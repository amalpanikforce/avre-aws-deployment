variable "aws_region" {
  description = "AWS region for CloudWatch log group."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used in resource names."
  type        = string
  default     = "avre"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "sandbox"
}

variable "cluster_name" {
  description = "Name of the ECS cluster created by the AWS infrastructure repo."
  type        = string
  default     = "avre-ecs-cluster"
}

variable "service_name" {
  description = "Name of the ECS task family and app service."
  type        = string
  default     = "avre-api"
}

variable "execution_role_arn" {
  description = "ARN of the existing ECS task execution role from the AWS infra repo."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the existing ECS task role from the AWS infra repo."
  type        = string
}

variable "log_group_name" {
  description = "Existing CloudWatch log group name created by the AWS infra repo."
  type        = string
  default     = "/ecs/avre-app"
}

variable "container_registry" {
  description = "ECR registry/account ID or registry hostname."
  type        = string
}

variable "container_repository" {
  description = "ECR repository name."
  type        = string
}

variable "container_version" {
  description = "Container image tag version to deploy."
  type        = string
  default     = "latest"
}

variable "container_image" {
  description = "Full container image to deploy. Derived from registry/repository/version when not provided."
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Subnet IDs from the AWS infra repo for the ECS service network configuration."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs from the AWS infra repo for the ECS service."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the ECS task."
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "Optional ALB target group ARN to attach this service to."
  type        = string
  default     = ""
}

variable "cpu" {
  description = "CPU units for the task definition."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory (MB) for the task definition."
  type        = number
  default     = 1024
}

variable "container_environment" {
  description = "Environment variables to inject into the container."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "Secrets to inject into the container."
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}
