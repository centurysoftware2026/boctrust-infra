resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

module "baseline" {
  source = "../modules/baseline"

  region       = var.region
  budget_email = var.budget_email
}

locals {
  # Subject prefix in this org's OIDC tokens (ID-based format).
  infra_sub = "repo:${var.github_org}@${var.github_org_id}/${var.infra_repo}@${var.infra_repo_id}"
}

# Terraform CI roles. Plan runs on pull requests with read access; apply runs only from main
# and only inside a protected GitHub environment, so production needs a manual approval.
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_sub}:pull_request", "${local.infra_sub}:ref:refs/heads/*"]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  name               = "boctrust-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "terraform_plan_read" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plans take the state lock, which writes a lock file next to the state.
data "aws_iam_policy_document" "plan_state" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "terraform_plan_state" {
  name   = "state-lock"
  role   = aws_iam_role.terraform_plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.infra_sub}:environment:staging",
        "${local.infra_sub}:environment:production",
      ]
    }
  }
}

# Terraform creates IAM roles, so apply needs broad rights. The trust policy above is what limits it:
# only runs from this repo, in a protected environment, after merge to main.
resource "aws_iam_role" "terraform_apply" {
  name               = "boctrust-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

resource "aws_iam_role_policy_attachment" "terraform_apply_admin" {
  role       = aws_iam_role.terraform_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
