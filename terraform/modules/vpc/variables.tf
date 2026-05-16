variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway for private subnet egress"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all AZs (cost saving for non-prod)"
  type        = bool
  default     = true
}
