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
  description = "Name of the ECS cluster."
  type        = string
  default     = "avre-sandbox-cluster"
}

variable "service_name" {
  description = "Name of the ECS service and task family."
  type        = string
  default     = "avre-api"
}

variable "container_image" {
  description = "Container image to deploy."
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Desired number of running tasks."
  type        = number
  default     = 1
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

variable "subnet_ids" {
  description = "Subnet IDs for the ECS service networking." 
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for ECS tasks."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the task."
  type        = bool
  default     = false
}

variable "health_check_grace_period_seconds" {
  description = "Grace period before ECS service health checks begin."
  type        = number
  default     = 60
}

variable "target_group_arn" {
  description = "Optional ALB target group ARN to attach the service to."
  type        = string
  default     = ""
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
