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

  service_name = "ecs"

  cluster_name = "avre-sandbox3-ecs-cluster"

  execution_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox3-ecs-execution-role"

  task_role_arn = "arn:aws:iam::526550911351:role/avre-sandbox3-ecs-task-role"

  log_group_name = "/ecs/avre-sandbox3-app"

  subnet_ids = [
    "subnet-045174f27b27e9440",
    "subnet-0645788b14974b7de"
  ]

  security_group_ids = [
    "sg-03874f162b97d4069"
  ]

  target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:526550911351:targetgroup/avre-sandbox3-tg/cb91a96ef03624c8"

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
    },
    {
      name  = "AVRE_APP_VERSION"
      value = "1.2.0"
    }
  ]

  container_secrets = [
    {
      name      = "DATABASE_CREDENTIALS"
      valueFrom = "arn:aws:secretsmanager:ap-south-1:526550911351:secret:avre-sandbox3-db-credentials-YYpHq5"
    }
  ]
}