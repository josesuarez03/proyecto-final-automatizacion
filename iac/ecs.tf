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
    security_groups  = [aws_security_group.security_group.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.monitoring.arn
  }

  # Load Balancer Configurations
  load_balancer {
  target_group_arn = aws_lb_target_group.ecs_tg_80.arn
  container_name   = "nginx"
  container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_3000.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_5601.arn
    container_name   = "kibana"
    container_port   = 5601
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_3306.arn
    container_name   = "mariadb"
    container_port   = 3306
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_lb_listener.http,
    aws_lb_listener.grafana,
    aws_lb_listener.kibana,
    aws_lb_listener.mariadb
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
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  # EFS volume for persistent data
  volume {
    name = "efs-monitoring"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.monitoring_data.id
      root_directory = "/"
    }
  }

  # Volumes for logs and configurations
  volume {
    name = "config-storage"
    docker_volume_configuration {
      scope  = "task"
      driver = "local"
    }
  }

  volume {
    name = "nginx-logs"
    docker_volume_configuration {
      scope  = "task"
      driver = "local"
    }
  }

  volume {
    name = "mysql-logs"
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
        "sh",
        "-c",
        <<-EOT
        aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/prometheus/prometheus.yml /config/prometheus/ && \
        aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/grafana/ /config/grafana/ --recursive && \
        aws s3 cp s3://${aws_s3_bucket.artifacts.id}/monitoring/elk/ /config/elk/ --recursive
        EOT
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
      name      = "api"
      image     = "${data.aws_ecr_repository.docker.repository_url}:api"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        { name = "DB_HOST", value = "localhost" },
        { name = "DB_USER", value = "admin" },
        { name = "DB_PASSWORD", value = "1234" },
        { name = "DB_NAME", value = "task_app" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      name      = "nginx"
      image     = "${data.aws_ecr_repository.docker.repository_url}:nginx"
      cpu       = 128
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort     = 80
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "nginx-logs"
          containerPath = "/var/log/nginx"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    },
    {
      name      = "nginx-exporter"
      image     = "nginx/nginx-prometheus-exporter:latest"
      cpu       = 64
      memory    = 128
      essential = false
      portMappings = [
        {
          containerPort = 9113
          hostPort     = 9113
          protocol     = "tcp"
        }
      ]
      environment = [
        { name = "NGINX_STATUS_URL", value = "http://localhost/metrics" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx-exporter"
        }
      }
    },
    {
      name      = "mariadb"
      image     = "mariadb:10.6"
      cpu       = 512
      memory    = 1024
      essential = true
      command   = [
        "--transaction-isolation=READ-COMMITTED",
        "--log-bin=binlog",
        "--binlog-format=ROW",
        "--general-log=1",
        "--general-log-file=/var/log/mysql/general.log",
        "--slow-query-log=1",
        "--slow-query-log-file=/var/log/mysql/slow.log"
      ]
      portMappings = [
        {
          containerPort = 3306
          hostPort     = 3306
          protocol     = "tcp"
        }
      ]
      environment = [
        { name = "MARIADB_ROOT_PASSWORD", value = "root" },
        { name = "MYSQL_PASSWORD", value = "1234" },
        { name = "MYSQL_DATABASE", value = "task_app" },
        { name = "MYSQL_USER", value = "admin" }
      ]
      mountPoints = [
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/var/lib/mysql"
          readOnly     = false
        },
        {
          sourceVolume  = "mysql-logs"
          containerPath = "/var/log/mysql"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mariadb"
        }
      }
    },
    {
      name      = "mariadb-exporter"
      image     = "prom/mysqld-exporter:latest"
      cpu       = 64
      memory    = 128
      essential = false
      portMappings = [
        {
          containerPort = 9104
          hostPort     = 9104
          protocol     = "tcp"
        }
      ]
      environment = [
        { name = "DATA_SOURCE_NAME", value = "admin:1234@tcp(localhost:3306)/task_app" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/monitoring-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mariadb-exporter"
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
        },
        {
          sourceVolume  = "nginx-logs"
          containerPath = "/var/log/nginx"
          readOnly     = true
        },
        {
          sourceVolume  = "mysql-logs"
          containerPath = "/var/log/mysql"
          readOnly     = true
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