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
  name_prefix          = local.name_prefix
  environment          = local.environment
  service_name         = local.service_name
  cluster_name         = "${local.name_prefix}-${local.environment}-cluster"
  container_image      = local.container_image
  container_port       = local.container_port
  desired_count        = local.desired_count
  cpu                  = local.cpu
  memory               = local.memory
  subnet_ids           = local.subnet_ids
  security_group_ids   = local.security_group_ids
  assign_public_ip     = local.assign_public_ip
  container_environment = local.container_environment
  container_secrets    = local.container_secrets
  aws_region           = local.aws_region
}
