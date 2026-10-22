data "aws_region" "current" {}

locals {
  full_name = "${var.env_name}-${var.name}"
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: pulls the image, writes logs, reads the secrets listed for this service.
resource "aws_iam_role" "execution" {
  name               = "${local.full_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for arn in values(var.secrets) : join(":", slice(split(":", arn), 0, 7))]
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name   = "read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_secrets[0].json
}

# Task role: what the application code itself may call. Attach extra policies from the environment root.
resource "aws_iam_role" "task" {
  name               = "${local.full_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_security_group" "service" {
  name        = local.full_name
  description = "Service ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = local.full_name }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count = var.alb == null ? 0 : 1

  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = var.alb.security_group_id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  description                  = "From the ALB"
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  count = var.internal_ingress_cidr == null ? 0 : 1

  security_group_id = aws_security_group.service.id
  cidr_ipv4         = var.internal_ingress_cidr
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  description       = "Service-to-service inside the VPC"
}

# Vendor APIs (BankOne, Smile ID, Dojah, Termii, SendGrid, Firebase) and the database go out through here.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound"
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.full_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # Graviton is about 20% cheaper than x86 on Fargate.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true

      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
      environment  = [for k, v in var.environment : { name = k, value = v }]
      secrets      = [for k, v in var.secrets : { name = k, valueFrom = v }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    }
  ])
}

resource "aws_service_discovery_service" "this" {
  count = var.enable_service_discovery ? 1 : 0

  name = var.name

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {}
}

resource "aws_lb_target_group" "this" {
  count = var.alb == null ? 0 : 1

  name        = substr(local.full_name, 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    path    = var.alb.health_check_path
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "this" {
  count = var.alb == null ? 0 : 1

  listener_arn = var.alb.listener_arn
  priority     = var.alb.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    http_header {
      http_header_name = "x-origin-verify"
      values           = [var.alb.origin_secret]
    }
  }

  condition {
    http_header {
      http_header_name = "x-target-service"
      values           = [var.name]
    }
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.alb == null ? [] : [1]

    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []

    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  # The deploy pipeline registers new task definitions, so Terraform must not revert them.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener_rule.this]
}
