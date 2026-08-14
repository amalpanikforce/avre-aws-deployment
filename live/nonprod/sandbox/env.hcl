locals {
  aws_region        = "us-east-1"
  name_prefix       = "avre"
  environment       = "sandbox"
  service_name      = "avre-api"
  container_image   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/avre:latest"
  container_port    = 8000
  desired_count     = 1
  cpu               = 512
  memory            = 1024
  subnet_ids        = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  security_group_ids = ["sg-12345678"]
  assign_public_ip  = false

  container_environment = [
    { name = "APP_ENV", value = "sandbox" },
    { name = "PORT", value = "8000" }
  ]

  container_secrets = []
}
