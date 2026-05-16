terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  # No NAT Gateway in dev — use VPC Endpoints to save cost
  enable_nat_gateway = false
}

module "eks" {
  source      = "../../modules/eks"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

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

  instance_class    = "db.t3.micro"
  multi_az          = false
  db_name           = "kubedevnews"
  # Credentials stored in SSM Parameter Store (free tier)
  ssm_path_prefix   = "/kube-news/dev/db"
}
