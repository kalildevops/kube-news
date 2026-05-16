terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "s3" {
    bucket         = "kube-news-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kube-news-tflock-prod"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "prod"
      Project     = "kube-news"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  environment = "prod"
  cidr        = var.vpc_cidr

  enable_nat_gateway = true
  single_nat_gateway = false  # one NAT per AZ for HA
}

module "eks" {
  source      = "../../modules/eks"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  node_instance_type = "m5.large"
  node_min           = 3
  node_max           = 6
  node_desired       = 3
}

module "rds" {
  source      = "../../modules/rds"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  allowed_security_group_id = module.eks.node_security_group_id
  engine                    = "aurora-postgresql"
  instance_class            = "db.serverless"
  multi_az                  = true
  db_name                   = "kubedevnews"
  use_secrets_manager       = true
  secrets_path              = "/kube-news/prod/db"
}

module "datadog" {
  source      = "../../modules/datadog"
  environment = "prod"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca        = module.eks.cluster_ca
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
