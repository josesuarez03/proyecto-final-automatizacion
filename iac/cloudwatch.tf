# KMS Key for CloudWatch Logs encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch Logs encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "cloudwatch-logs-key"
  }
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_stack" {
  name              = "/ecs/api-stack"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "mariadb_stack" {
  name              = "/ecs/mariadb-stack"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name              = "/aws/ecs/monitoring-cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_cpu" {
  alarm_name          = "api-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de CPU supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.api_service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_memory" {
  alarm_name          = "api-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de memoria supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.api_service.name
  }
}

# CloudWatch Metric Alarms for MariaDB Service
resource "aws_cloudwatch_metric_alarm" "mariadb_cpu" {
  alarm_name          = "mariadb-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de CPU de MariaDB supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.mariadb_service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "mariadb_memory" {
  alarm_name          = "mariadb-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de memoria de MariaDB supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.mariadb_service.name
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "ecs" {
  dashboard_name = "ECS-Monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.api_service.name, "ClusterName", aws_ecs_cluster.ecs_cluster.name],
            [".", ".", "ServiceName", aws_ecs_service.mariadb_service.name, "ClusterName", aws_ecs_cluster.ecs_cluster.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CPU Utilization by Service"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_service.api_service.name, "ClusterName", aws_ecs_cluster.ecs_cluster.name],
            [".", ".", "ServiceName", aws_ecs_service.mariadb_service.name, "ClusterName", aws_ecs_cluster.ecs_cluster.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Memory Utilization by Service"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.ecs_alb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.ecs_alb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "HTTP 5XX Errors"
          view   = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Número de errores 5XX superior a 10 en 5 minutos"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.ecs_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "alb-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Latencia promedio superior a 5 segundos"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.ecs_alb.arn_suffix
  }
}

# SNS Topic para las alertas
resource "aws_sns_topic" "alerts" {
  name = "ecs-alerts"
  kms_master_key_id = aws_kms_key.cloudwatch.id
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}