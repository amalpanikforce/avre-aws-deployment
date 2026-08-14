locals {
  env_config_path    = "${get_terragrunt_dir()}/env.hcl"
  cluster_aws_region = fileexists(local.env_config_path) ? read_terragrunt_config(local.env_config_path).locals.aws_region : get_env("AWS_REGION", "us-east-1")
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.cluster_aws_region}"
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "avre-aws-state-bucket-${local.cluster_aws_region}"
    key            = "deployment/${path_relative_to_include()}/terraform.tfstate"
    region         = local.cluster_aws_region
    use_lockfile   = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
