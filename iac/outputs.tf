output "ecs_cluster_name" {
  value       = aws_ecs_cluster.ecs_cluster.name
  description = "Name of the ECS cluster"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.monitoring_stack.arn
  description = "ARN of the ECS task definition"
}

# Outputs para referencia
output "bucket_name" {
  description = "Nombre del bucket de artefactos"
  value       = aws_s3_bucket.artifacts.id
}

output "bucket_arn" {
  description = "ARN del bucket de artefactos"
  value       = aws_s3_bucket.artifacts.arn
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.monitoring_stack.name
  description = "Name of the CloudWatch log group"
}