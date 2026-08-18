locals {
  aws_region = "ap-south-1"

  name_prefix = "avre"
  environment = "sandbox3"

  backend = {
    bucket       = "avre-terraform-state-ap-south-1"
    key          = "deployment/nonprod/sandbox3/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  service_name = "app"

  cluster_name = "avre-sandbox3-ecs-cluster"

  execution_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox3-ecs-execution-role"

  task_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox3-ecs-task-role"

  log_group_name = "/ecs/avre-sandbox3-app"

  subnet_ids = [
    "subnet-02998840567a2f5d9",
    "subnet-08e8b901b98747bee"
  ]

  security_group_ids = [
    "sg-0606d6b31088f2829"
  ]

  target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:526550911351:targetgroup/avre-sandbox3-tg/a8ba444ad5b875e9"

  repository_credentials_arn = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox3-ghcr-credentials-7D6Khr"

  container_port = 8000

  cpu    = 512
  memory = 1024

  desired_count = 1

  assign_public_ip = false

  container_environment = [
    {
      name  = "APP_ENV"
      value = "sandbox3"
    },
    {
      name  = "PORT"
      value = "8000"
    },
    {
      name  = "AVRE_RUNTIME_MODE"
      value = "local"
    },
    {
      name  = "AVRE_ENVIRONMENT_NAME"
      value = "aws-sandbox3"
    },
    {
      name  = "AVRE_DEPLOYMENT_KEY"
      value = "acme_qsr"
    },
    {
      name  = "AVRE_DB_PROVIDER"
      value = "postgres"
    },
    {
      name  = "AVRE_DB_HOST"
      value = "avre-sandbox3-postgres.cacmm2raj5wo.ap-south-1.rds.amazonaws.com"
    },
    {
      name  = "AVRE_DB_SSL_MODE"
      value = "require"
    },
    {
      name  = "AVRE_STORAGE_PROVIDER"
      value = "local"
    },
    {
      name  = "AVRE_AUTH_MODE"
      value = "none"
    },
    {
      name  = "AVRE_LOG_LEVEL"
      value = "INFO"
    }
    # AVRE_APP_VERSION is injected at deploy time by deploy.sh via -var app_version
  ]

  container_secrets = [
    {
      name      = "DATABASE_CREDENTIALS"
      valueFrom = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox3-db-credentials-XgRsgf"
    }
  ]
}