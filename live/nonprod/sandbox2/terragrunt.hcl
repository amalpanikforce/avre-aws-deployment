include "env" {
  path   = "${get_terragrunt_dir()}/env.hcl"
  expose = true
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

remote_state {
  backend = "s3"

  config = {
    bucket       = include.env.locals.backend.bucket
    key          = include.env.locals.backend.key
    region       = include.env.locals.backend.region
    encrypt      = include.env.locals.backend.encrypt
    use_lockfile = include.env.locals.backend.use_lockfile
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform {
  source = "../../../modules/ecs-deployment"
}

inputs = {
  aws_region            = include.env.locals.aws_region
  name_prefix           = include.env.locals.name_prefix
  environment           = include.env.locals.environment
  service_name          = include.env.locals.service_name

  cluster_name          = include.env.locals.cluster_name
  execution_role_arn    = include.env.locals.execution_role_arn
  task_role_arn         = include.env.locals.task_role_arn
  log_group_name        = include.env.locals.log_group_name

  subnet_ids            = include.env.locals.subnet_ids
  security_group_ids    = include.env.locals.security_group_ids
  target_group_arn      = include.env.locals.target_group_arn

  container_repository  = include.env.locals.container_repository
  container_version     = include.env.locals.container_version
  container_port        = include.env.locals.container_port

  cpu                   = include.env.locals.cpu
  memory                = include.env.locals.memory
  desired_count         = include.env.locals.desired_count
  assign_public_ip      = include.env.locals.assign_public_ip

  container_environment = include.env.locals.container_environment
  container_secrets     = include.env.locals.container_secrets
}