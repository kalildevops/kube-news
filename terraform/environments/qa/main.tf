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
    bucket         = "kube-news-tfstate-qa"
    key            = "qa/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kube-news-tflock-qa"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "qa"
      Project     = "kube-news"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  environment = "qa"
  cidr        = var.vpc_cidr

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source      = "../../modules/eks"
  environment = "qa"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  node_instance_type = "t3.medium"
  node_min           = 2
  node_max           = 4
  node_desired       = 2
}

module "rds" {
  source      = "../../modules/rds"
  environment = "qa"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  allowed_security_group_id = module.eks.node_security_group_id
  instance_class            = "db.t3.small"
  multi_az                  = false
  db_name                   = "kubedevnews"
  use_secrets_manager       = true
  secrets_path              = "/kube-news/qa/db"
}

module "datadog" {
  source      = "../../modules/datadog"
  environment = "qa"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca        = module.eks.cluster_ca
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
