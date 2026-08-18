data "aws_cloudwatch_log_group" "this" {
  name = var.log_group_name
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-${var.environment}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    merge(
      {
        name      = var.service_name
        image     = var.container_image
        essential = true
        cpu       = var.cpu
        memory    = var.memory

        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = var.container_port
            protocol      = "tcp"
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"

          options = {
            awslogs-group         = var.log_group_name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = var.service_name
          }
        }

        command     = var.container_command
        environment = var.container_environment
        secrets     = var.container_secrets
      },

      var.repository_credentials_arn != "" ? {
        repositoryCredentials = {
          credentialsParameter = var.repository_credentials_arn
        }
      } : {}
    )
  ])

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-${var.service_name}"
    Environment = var.environment
    ManagedBy   = "Terragrunt"
    ClusterName = var.cluster_name
    Product     = "AVRE"
    DeployedBy  = "AVRE Team"
    Owner       = "AVRE Cloud Team"
  }
}

resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == "" ? [] : [var.target_group_arn]

    content {
      target_group_arn = load_balancer.value
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-${var.service_name}"
    Environment = var.environment
    ManagedBy   = "Terragrunt"
    ClusterName = var.cluster_name
    Product     = "AVRE"
    DeployedBy  = "AVRE Team"
    Owner       = "AVRE Cloud Team"
  }
}