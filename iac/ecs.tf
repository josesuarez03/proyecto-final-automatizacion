resource "aws_ecs_cluster" "ecs_cluster" {
  name = "monitoring-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name    = "/aws/ecs/monitoring-cluster"
      }
    }
  }

  tags = {
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}

# Configuración de Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 70
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 30
    capacity_provider = "FARGATE_SPOT"
  }
}

# Servicio ECS
resource "aws_ecs_service" "monitoring_service" {
  name                               = "monitoring-service"
  cluster                           = aws_ecs_cluster.ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.monitoring_stack.arn
  desired_count                     = 2
  health_check_grace_period_seconds = 120
  enable_execute_command           = true
  enable_ecs_managed_tags         = true
  propagate_tags                  = "SERVICE"
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 70
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 30
  }

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.monitoring.arn
  }

  # Load Balancer Configurations
  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kibana.arn
    container_name   = "kibana"
    container_port   = 5601
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.elasticsearch.arn
    container_name   = "elasticsearch"
    container_port   = 9200
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role,
    aws_lb_listener.front_end
  ]
}

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name        = "monitoring.local"
  description = "Service discovery namespace for monitoring services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "monitoring" {
  name = "monitoring"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Crear los sistemas de archivos EFS
resource "aws_efs_file_system" "monitoring_data" {
  creation_token = "monitoring-data"
  encrypted      = true

  tags = {
    Name = "MonitoringData"
  }
}

resource "aws_efs_mount_target" "monitoring_mount_1" {
  file_system_id  = aws_efs_file_system.monitoring_data.id
  subnet_id       = aws_subnet.public_1.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "monitoring_mount_2" {
  file_system_id  = aws_efs_file_system.monitoring_data.id
  subnet_id       = aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

data "aws_ecr_repository" "docker" {
  name = "docker"
}

# Task Definition
resource "aws_ecs_task_definition" "monitoring_stack" {
  family                   = "monitoring-stack"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "4096"
  memory                  = "8192"
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  # EFS volume para datos persistentes
  volume {
    name = "efs-monitoring"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.monitoring_data.id
      root_directory = "/"
    }
  }

  # Volúmenes temporales para configuraciones
  volume {
    name = "config-storage"
    docker_volume_configuration {
      scope  = "task"
      driver = "local"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "config-init"
      image     = "amazon/aws-cli:latest"
      essential = false
      command   = [
        "sh", "-c", 
        "aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/prometheus/prometheus.yml /config/prometheus/ && \
         aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/grafana/ /config/grafana/ --recursive && \
         aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/elk/ /config/elk/ --recursive"
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/config"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "config-init"
        }
      }
    },
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      cpu       = 256
      memory    = 512
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition    = "SUCCESS"
        }
      ]
      portMappings = [
        {
          containerPort = 9090
          hostPort     = 9090
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/etc/prometheus"
          readOnly     = true
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    },
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      cpu       = 256
      memory    = 512
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition    = "SUCCESS"
        }
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort     = 3000
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/etc/grafana"
          readOnly     = true
        },
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/var/lib/grafana"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    },
    {
      name      = "elasticsearch"
      image     = "elasticsearch:7.9.1"
      cpu       = 1024
      memory    = 2048
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition    = "SUCCESS"
        }
      ]
      portMappings = [
        {
          containerPort = 9200
          hostPort     = 9200
          protocol     = "tcp"
        },
        {
          containerPort = 9300
          hostPort     = 9300
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/usr/share/elasticsearch/config"
          readOnly     = true
        },
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/usr/share/elasticsearch/data"
          readOnly     = false
        }
      ]
      environment = [
        { name = "discovery.type", value = "single-node" },
        { name = "ES_JAVA_OPTS", value = "-Xms1g -Xmx1g" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "elasticsearch"
        }
      }
    },
    {
      name      = "logstash"
      image     = "logstash:7.9.1"
      cpu       = 512
      memory    = 1024
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition    = "SUCCESS"
        },
        {
          containerName = "elasticsearch"
          condition    = "START"
        }
      ]
      portMappings = [
        {
          containerPort = 5044
          hostPort     = 5044
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/usr/share/logstash/config"
          readOnly     = true
        },
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/usr/share/logstash/data"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "logstash"
        }
      }
    },
    {
      name      = "kibana"
      image     = "kibana:7.9.1"
      cpu       = 256
      memory    = 512
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition    = "SUCCESS"
        },
        {
          containerName = "elasticsearch"
          condition    = "START"
        }
      ]
      portMappings = [
        {
          containerPort = 5601
          hostPort     = 5601
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "config-storage"
          containerPath = "/usr/share/kibana/config"
          readOnly     = true
        }
      ]
      environment = [
        { name = "ELASTICSEARCH_HOSTS", value = "http://localhost:9200" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "kibana"
        }
      }
    }
  ])

  tags = {
    Name = "MonitoringStack"
  }
}