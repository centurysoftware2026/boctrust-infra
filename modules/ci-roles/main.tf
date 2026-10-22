data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

data "aws_iam_policy_document" "backend_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.backend_repo}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "backend_deploy" {
  name                 = "${var.name}-backend-deploy"
  assume_role_policy   = data.aws_iam_policy_document.backend_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "backend_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }

  # Describe and register actions do not support resource-level restrictions.
  statement {
    sid = "EcsTaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:ListTaskDefinitions",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
    ]
    resources = [
      var.cluster_arn,
      "arn:aws:ecs:${local.region}:${local.account_id}:service/${split("/", var.cluster_arn)[1]}/*",
      "arn:aws:ecs:${local.region}:${local.account_id}:task/${split("/", var.cluster_arn)[1]}/*",
      "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${var.name}-*:*",
    ]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = var.ecs_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "backend_deploy" {
  name   = "deploy"
  role   = aws_iam_role.backend_deploy.id
  policy = data.aws_iam_policy_document.backend_deploy.json
}

data "aws_iam_policy_document" "admin_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.admin_repo}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "admin_deploy" {
  name                 = "${var.name}-admin-deploy"
  assume_role_policy   = data.aws_iam_policy_document.admin_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "admin_deploy" {
  statement {
    sid       = "SyncSite"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${var.admin_site_bucket_arn}/*"]
  }

  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [var.admin_site_bucket_arn]
  }

  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [var.distribution_arn]
  }
}

resource "aws_iam_role_policy" "admin_deploy" {
  name   = "deploy"
  role   = aws_iam_role.admin_deploy.id
  policy = data.aws_iam_policy_document.admin_deploy.json
}
