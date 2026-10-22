data "aws_region" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-db-init-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "read_master_secret" {
  name = "read-master-secret"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_master_secret_arn]
    }]
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-db-init"
  description = "One-off task that creates the service databases"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db-init" }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Database and image pull"
}

# Run once after the first apply:
#   aws ecs run-task --cluster <cluster> --launch-type FARGATE --task-definition <family> \
#     --network-configuration "awsvpcConfiguration={subnets=[<private>],securityGroups=[<sg>]}"
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name}-db-init"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "db-init"
      image     = "postgres:16-alpine"
      essential = true

      entryPoint = ["sh", "-c"]
      command = [
        join("; ", [
          for db in var.databases :
          "psql -d postgres -tc \"SELECT 1 FROM pg_database WHERE datname='${db}'\" | grep -q 1 || psql -d postgres -c \"CREATE DATABASE ${db}\""
        ])
      ]

      environment = [
        { name = "PGHOST", value = var.db_endpoint },
        { name = "PGPORT", value = "5432" },
        { name = "PGSSLMODE", value = "require" },
      ]

      secrets = [
        { name = "PGUSER", valueFrom = "${var.db_master_secret_arn}:username::" },
        { name = "PGPASSWORD", valueFrom = "${var.db_master_secret_arn}:password::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "db-init"
        }
      }
    }
  ])
}
