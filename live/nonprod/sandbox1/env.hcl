locals {
  aws_region = "ap-south-1"

  name_prefix = "avre"
  environment = "sandbox1"

  backend = {
    bucket       = "avre-terraform-state-ap-south-1"
    key          = "deployment/nonprod/sandbox1/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  service_name = "ecs"

  cluster_name = "avre-sandbox1-ecs-cluster"

  execution_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox1-ecs-execution-role"

  task_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox1-ecs-task-role"

  log_group_name = "/ecs/avre-sandbox1-app"

  subnet_ids = [
    "subnet-0b68133fa60867953",
    "subnet-0dfe72915a3ec5231"
  ]

  security_group_ids = [
    "sg-0715d12c885a56d35"
  ]

  target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:526550911351:targetgroup/avre-sandbox1-tg/07a64358f370b4f7"

  container_repository = "avre-shared-ecr"

  container_version = "aa615867dc1abeb7c6bb12cb457dd20a132286d9"

  container_port = 8000

  cpu    = 512
  memory = 1024

  desired_count = 1

  assign_public_ip = false

  container_environment = [
    {
      name  = "APP_ENV"
      value = "sandbox1"
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
      value = "avre-sandbox1-postgres.cacmm2raj5wo.ap-south-1.rds.amazonaws.com"
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
      valueFrom = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox1-db-credentials-4oywoK"
    }
  ]
}