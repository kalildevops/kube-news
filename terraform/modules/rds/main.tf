terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  name          = "kube-news-${var.environment}"
  is_aurora     = var.engine == "aurora-postgresql"
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "Allow PostgreSQL from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-rds" }
}

# ── Subnet Group ──────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.subnet_ids
  tags       = { Name = local.name }
}

# ── Random Password ───────────────────────────────────────────────────────────

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── SSM Parameter Store (dev — free tier) ─────────────────────────────────────

resource "aws_ssm_parameter" "db_password" {
  count = var.use_secrets_manager ? 0 : 1

  name        = "${var.ssm_path_prefix}/password"
  description = "RDS master password for ${local.name}"
  type        = "SecureString"
  value       = random_password.db.result

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_host" {
  count = var.use_secrets_manager ? 0 : 1

  name  = "${var.ssm_path_prefix}/host"
  type  = "String"
  value = local.is_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].address
}

resource "aws_ssm_parameter" "db_username" {
  count = var.use_secrets_manager ? 0 : 1

  name  = "${var.ssm_path_prefix}/username"
  type  = "String"
  value = var.db_username
}

# ── Secrets Manager (qa / prod — with rotation support) ──────────────────────

resource "aws_secretsmanager_secret" "db" {
  count = var.use_secrets_manager ? 1 : 0

  name                    = var.secrets_path
  description             = "RDS credentials for ${local.name}"
  recovery_window_in_days = var.environment == "prod" ? 7 : 0
}

resource "aws_secretsmanager_secret_version" "db" {
  count     = var.use_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.db[0].id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = local.is_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].address
    port     = 5432
    dbname   = var.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ── RDS Instance (dev / qa — postgres engine) ─────────────────────────────────

resource "aws_db_instance" "this" {
  count = local.is_aurora ? 0 : 1

  identifier           = local.name
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = 20
  storage_type         = "gp3"
  storage_encrypted    = true
  db_name              = var.db_name
  username             = var.db_username
  password             = random_password.db.result
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az             = var.multi_az
  skip_final_snapshot  = var.environment != "prod"
  deletion_protection  = var.environment == "prod"
  backup_retention_period = var.environment == "prod" ? 7 : 1

  tags = { Name = local.name }
}

# ── Aurora Serverless v2 (prod) ───────────────────────────────────────────────

resource "aws_rds_cluster" "this" {
  count = local.is_aurora ? 1 : 0

  cluster_identifier      = local.name
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  storage_encrypted       = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${local.name}-final"
  deletion_protection     = true
  backup_retention_period = 7

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4
  }

  tags = { Name = local.name }
}

resource "aws_rds_cluster_instance" "this" {
  count = local.is_aurora ? 2 : 0

  identifier         = "${local.name}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version
}
