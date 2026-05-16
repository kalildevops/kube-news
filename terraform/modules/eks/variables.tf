variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS nodes"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
}

variable "node_min" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_desired" {
  description = "Desired number of nodes"
  type        = number
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}
