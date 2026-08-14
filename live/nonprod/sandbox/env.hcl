locals {
  aws_region            = "us-east-1"
  name_prefix           = "avre"
  environment           = "sandbox"
  cluster_name          = "avre-ecs-cluster"
  service_name          = "avre-api"
  execution_role_arn    = "arn:aws:iam::123456789012:role/avre-ecs-execution-role"
  task_role_arn         = "arn:aws:iam::123456789012:role/avre-ecs-task-role"
  log_group_name        = "/ecs/avre-app"
  vpc_id                = "vpc-xxxxxxxx"
  subnet_ids            = ["subnet-aaaaaaa", "subnet-bbbbbbb"]
  security_group_ids    = ["sg-cccccccc"]
  desired_count         = 1
  assign_public_ip      = false
  target_group_arn      = ""
  container_registry    = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
  container_repository  = "avre"
  container_version     = "latest"
  container_port        = 8000
  cpu                   = 512
  memory                = 1024

  container_environment = [
    { name = "APP_ENV", value = "sandbox" },
    { name = "PORT", value = "8000" }
  ]

  container_secrets = []
}
