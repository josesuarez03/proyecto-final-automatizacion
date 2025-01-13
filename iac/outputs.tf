output "ecs_cluster_name" {
  value       = aws_ecs_cluster.ecs_cluster.name
  description = "Name of the ECS cluster"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.services_stack.arn
  description = "ARN of the ECS task definition"
}

output "bucket_name" {
  description = "Nombre del bucket de artefactos"
  value       = aws_s3_bucket.artifacts.id
}

output "bucket_arn" {
  description = "ARN del bucket de artefactos"
  value       = aws_s3_bucket.artifacts.arn
}

output "alb_dns_name" {
  value       = aws_lb.ecs_alb.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "service_security_group_id" {
  value       = aws_security_group.security_group.id
  description = "ID of the ECS service security group"
}

output "ecs_service_name" {
  value       = aws_ecs_service.services_stack.name
  description = "Name of the ECS service"
}

output "cloudwatch_dashboard_url" {
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.ecs.dashboard_name}"
  description = "URL of the CloudWatch dashboard"
}
