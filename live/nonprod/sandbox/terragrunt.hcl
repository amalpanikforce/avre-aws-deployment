include "env" {
  path   = "${get_repo_root()}/live/nonprod/sandbox/env.hcl"
  expose = true
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecs-deployment"
}

inputs = {
  name_prefix           = local.name_prefix
  environment           = local.environment
  cluster_name          = local.cluster_name
  service_name          = local.service_name
  execution_role_arn    = local.execution_role_arn
  task_role_arn         = local.task_role_arn
  log_group_name        = local.log_group_name
  subnet_ids            = local.subnet_ids
  security_group_ids    = local.security_group_ids
  desired_count         = local.desired_count
  assign_public_ip      = local.assign_public_ip
  target_group_arn      = local.target_group_arn
  container_registry    = local.container_registry
  container_repository  = local.container_repository
  container_version     = local.container_version
  container_port        = local.container_port
  cpu                   = local.cpu
  memory                = local.memory
  container_environment = local.container_environment
  container_secrets     = local.container_secrets
  aws_region            = local.aws_region
}
