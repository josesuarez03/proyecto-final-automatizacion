# Alarma de CPU alta en el cluster
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "ecs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de CPU supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }
}

# Alarma de memoria alta en el cluster
resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Este alarma se dispara cuando el uso de memoria supera el 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }
}

# Alarma para tareas en estado RUNNING
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name          = "ecs-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Este alarma se dispara cuando hay menos de 1 tarea ejecutándose"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }
}

# SNS Topic para las alertas
resource "aws_sns_topic" "alerts" {
  name = "ecs-alerts"
}

# Política del SNS Topic
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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

# Dashboard de CloudWatch
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
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.ecs_cluster.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CPU Utilization"
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
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.ecs_cluster.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Memory Utilization"
        }
      }
    ]
  })
}

# Log group principal para el stack de monitoreo
resource "aws_cloudwatch_log_group" "monitoring_stack" {
  name              = "/ecs/monitoring-stack"
  retention_in_days = 14

  tags = {
    Environment = "production"
    Application = "monitoring-stack"
  }
}

# Log groups específicos para cada servicio
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/monitoring-stack/api"
  retention_in_days = 14

  tags = {
    Service     = "api"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/monitoring-stack/nginx"
  retention_in_days = 14

  tags = {
    Service     = "nginx"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "mariadb" {
  name              = "/ecs/monitoring-stack/mariadb"
  retention_in_days = 14

  tags = {
    Service     = "mariadb"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/monitoring-stack/prometheus"
  retention_in_days = 14

  tags = {
    Service     = "prometheus"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/monitoring-stack/grafana"
  retention_in_days = 14

  tags = {
    Service     = "grafana"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "elasticsearch" {
  name              = "/ecs/monitoring-stack/elasticsearch"
  retention_in_days = 14

  tags = {
    Service     = "elasticsearch"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "logstash" {
  name              = "/ecs/monitoring-stack/logstash"
  retention_in_days = 14

  tags = {
    Service     = "logstash"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "kibana" {
  name              = "/ecs/monitoring-stack/kibana"
  retention_in_days = 14

  tags = {
    Service     = "kibana"
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_group" "exporters" {
  name              = "/ecs/monitoring-stack/exporters"
  retention_in_days = 14

  tags = {
    Service     = "exporters"
    Environment = "production"
  }
}