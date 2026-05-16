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
    bucket         = "kube-news-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kube-news-tflock-dev"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "kube-news"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  environment = "dev"
  cidr        = var.vpc_cidr

  # No NAT Gateway in dev — VPC Endpoints handle ECR/SSM/Secrets access
  enable_nat_gateway = false
}

module "eks" {
  source      = "../../modules/eks"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  # In dev, nodes go in public subnets (no NAT needed, SGs restrict inbound)
  subnet_ids  = module.vpc.public_subnet_ids

  node_instance_type = "t3.micro"
  node_min           = 1
  node_max           = 2
  node_desired       = 1
}

module "rds" {
  source      = "../../modules/rds"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  allowed_security_group_id = module.eks.node_security_group_id
  instance_class            = "db.t3.micro"
  multi_az                  = false
  db_name                   = "kubedevnews"
  use_secrets_manager       = false
  ssm_path_prefix           = "/kube-news/dev/db"
}

module "datadog" {
  source      = "../../modules/datadog"
  environment = "dev"

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca       = module.eks.cluster_ca
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
