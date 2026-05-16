terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  instance_class  = "db.t3.small"
  multi_az        = false
  db_name         = "kubedevnews"
  # Credentials stored in Secrets Manager with auto-rotation
  use_secrets_manager = true
  secrets_path        = "/kube-news/qa/db"
}
