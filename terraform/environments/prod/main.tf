terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  enable_nat_gateway      = true
  single_nat_gateway      = false  # one per AZ for HA
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

  # Aurora Serverless v2 for prod — auto-scales, Multi-AZ native
  engine              = "aurora-postgresql"
  instance_class      = "db.serverless"
  multi_az            = true
  db_name             = "kubedevnews"
  use_secrets_manager = true
  secrets_path        = "/kube-news/prod/db"
}
