output "endpoint" {
  value = local.is_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].address
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
