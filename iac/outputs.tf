output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Name of the ECS cluster"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.app_task.arn
  description = "ARN of the ECS task definition"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.api.repository_url
  description = "URL of the ECR repository"
}

output "artifacts_bucket_name" {
  value       = aws_s3_bucket.artifacts.id
  description = "Name of the artifacts S3 bucket"
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.ecs_logs.name
  description = "Name of the CloudWatch log group"
}