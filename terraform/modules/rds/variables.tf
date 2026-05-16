variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID of EKS nodes (allowed to connect)"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "engine" {
  description = "Database engine: postgres or aurora-postgresql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "kubedevnews"
}

variable "use_secrets_manager" {
  description = "Store credentials in Secrets Manager (true) or SSM Parameter Store (false)"
  type        = bool
  default     = false
}

variable "ssm_path_prefix" {
  description = "SSM Parameter Store path prefix (used when use_secrets_manager = false)"
  type        = string
  default     = ""
}

variable "secrets_path" {
  description = "Secrets Manager secret name prefix (used when use_secrets_manager = true)"
  type        = string
  default     = ""
}
