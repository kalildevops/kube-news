variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "EKS cluster CA certificate (base64)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  type        = string
}

variable "datadog_api_key_secret_name" {
  description = "Name of the Secrets Manager secret containing the DataDog API key"
  type        = string
  default     = "datadog/api-key"
}

variable "datadog_site" {
  description = "DataDog site (e.g. datadoghq.com or datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
}
