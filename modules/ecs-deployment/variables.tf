variable "aws_region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "container_image" {
  description = "Full OCI container image reference (e.g. ghcr.io/kcs-platform-engineering/avre:v2.3.0 or docker.io/owner/repo:tag)"
  type        = string
}

variable "repository_credentials_arn" {
  description = "Optional AWS Secrets Manager ARN containing username and PAT for pulling private container images"
  type        = string
  default     = ""
}

variable "container_port" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type = bool
}

variable "target_group_arn" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "container_environment" {
  type = list(object({
    name  = string
    value = string
  }))
}

variable "container_secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
}

variable "container_command" {
  description = "Optional override for container command (e.g. running Alembic DB migrations before starting app)"
  type        = list(string)
  default     = ["sh", "-c", "alembic upgrade head && exec python -m uvicorn avre_api:app --host 0.0.0.0 --port 8000"]
}

variable "app_version" {
  description = "Deployed application version (e.g. 1.0.3). Injected as AVRE_APP_VERSION env var into the container at deploy time."
  type        = string
}