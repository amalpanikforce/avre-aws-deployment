locals {
  aws_region = "ap-south-1"

  name_prefix = "avre"
  environment = "sandbox"

  backend = {
    bucket       = "avre-terraform-state-ap-south-1"
    key          = "deployment/nonprod/sandbox/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  service_name = "app"

  cluster_name = "avre-sandbox-ecs-cluster"

  execution_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox-ecs-execution-role"

  task_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox-ecs-task-role"

  log_group_name = "/ecs/avre-sandbox-app"

  subnet_ids = [
    "subnet-0601980bf5ddfac24",
    "subnet-0fce8262bd35f61b4"
  ]

  security_group_ids = [
    "sg-02fc95b3ab8b6919a"
  ]

  target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:526550911351:targetgroup/avre-sandbox-tg/d2eb7a0ea91546c9"

  container_image = "ghcr.io/kcs-platform-engineering/avre@sha256:66c1dc3fde51c0aa7208548c844e2759a6217bfbaeb41386d15d4058c7b8ca07"

  repository_credentials_arn = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox-ghcr-credentials-7D6Khr"

  container_port = 8000

  cpu    = 512
  memory = 1024

  desired_count = 1

  assign_public_ip = false

  container_environment = [
    {
      name  = "APP_ENV"
      value = "sandbox"
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
      value = "aws-sandbox"
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
      value = "avre-sandbox-postgres.cacmm2raj5wo.ap-south-1.rds.amazonaws.com"
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
    },
    {
      name  = "AVRE_APP_VERSION"
      value = "1.2.0"
    }
  ]

  container_secrets = [
    {
      name      = "DATABASE_CREDENTIALS"
      valueFrom = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox-db-credentials-6sM6cb"
    }
  ]
}