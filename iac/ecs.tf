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

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name        = "monitoring.local"
  description = "Service discovery namespace for monitoring services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "mariadb" {
  name = "mariadb"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# EFS File System
resource "aws_efs_file_system" "monitoring_data" {
  creation_token = "monitoring-data"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "MonitoringData"
  }
}

# Mount Targets
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

# Access Points
resource "aws_efs_access_point" "mysql_data" {
  file_system_id = aws_efs_file_system.monitoring_data.id

  root_directory {
    path = "/mysql_data"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }

  posix_user {
    gid = 999
    uid = 999
    secondary_gids = [999]
  }
}

resource "aws_efs_access_point" "mysql_logs" {
  file_system_id = aws_efs_file_system.monitoring_data.id

  root_directory {
    path = "/mysql_logs"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }

  posix_user {
    gid = 999
    uid = 999
    secondary_gids = [999]
  }
}

resource "aws_efs_access_point" "nginx_logs" {
  file_system_id = aws_efs_file_system.monitoring_data.id

  root_directory {
    path = "/nginx_logs"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = "755"
    }
  }

  posix_user {
    gid = 0
    uid = 0
  }
}

resource "aws_efs_access_point" "prometheus_data" {
  file_system_id = aws_efs_file_system.monitoring_data.id

  root_directory {
    path = "/prometheus_data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }
}

resource "aws_efs_access_point" "grafana_data" {
  file_system_id = aws_efs_file_system.monitoring_data.id

  root_directory {
    path = "/grafana_data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }
}


data "aws_ecr_repository" "docker" {
  name = "docker"
}

# Task Definition para API y Nginx
resource "aws_ecs_task_definition" "api_stack" {
  family                   = "api-stack"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "2048"  # Increased CPU for additional containers
  memory                  = "4096"  # Increased memory for additional containers
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  volume {
    name = "nginx_logs"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.nginx_logs.id
        iam            = "ENABLED"
      }
    }
  }

  volume {
    name = "prometheus_data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_data.id
        iam            = "ENABLED"
      }
    }
  }

  volume {
    name = "grafana_data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.grafana_data.id
        iam            = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${data.aws_ecr_repository.docker.repository_url}:api"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        { name = "DB_HOST", value = "mariadb.monitoring.local" },
        { name = "DB_USER", value = "admin" },
        { name = "DB_PASSWORD", value = "1234" },
        { name = "DB_NAME", value = "task_app" }
      ]
      portMappings = [
        {
          containerPort = 5000
          protocol     = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      name      = "nginx"
      image     = "${data.aws_ecr_repository.docker.repository_url}:nginx"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort     = 80
          protocol     = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "api"
          condition    = "START"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "nginx_logs"
          containerPath = "/var/log/nginx"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    },
    {
      name      = "nginx-exporter"
      image     = "public.ecr.aws/nginx/nginx-prometheus-exporter:latest"
      cpu       = 128
      memory    = 256
      essential = false
      command   = [
        "-nginx.scrape-uri=http://localhost/nginx_status"
      ]
      portMappings = [
        {
          containerPort = 9113
          protocol     = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "nginx"
          condition    = "START"
        }
      ]
    },
    {
      name      = "mariadb-exporter"
      image     = "public.ecr.aws/bitnami/mysqld-exporter:latest"
      cpu       = 128
      memory    = 256
      essential = false
      environment = [
        {
          name  = "DATA_SOURCE_NAME"
          value = "admin:1234@(mariadb.monitoring.local:3306)/task_app"
        }
      ]
      portMappings = [
        {
          containerPort = 9104
          protocol     = "tcp"
        }
      ]
    },
    {
      name      = "prometheus"
      image     = "public.ecr.aws/ubuntu/prometheus:2.53.3-24.04_stable"
      cpu       = 512
      memory    = 1024
      essential = true
      command   = [
        "sh",
        "-c",
        "aws s3 cp s3://artifacts-${data.aws_caller_identity.current.account_id}/monitoring/prometheus/prometheus.yml /etc/prometheus/prometheus.yml && chmod 644 /etc/prometheus/prometheus.yml && prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus"
      ]
      portMappings = [
        {
          containerPort = 9090
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus_data"
          containerPath = "/prometheus"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    },
    {
      name      = "grafana"
      image     = "public.ecr.aws/ubuntu/grafana:11.0.0-22.04_stable"
      cpu       = 512
      memory    = 1024
      essential = true
      command   = [
        "sh",
        "-c",
        "aws s3 cp s3://artifacts-${data.aws_caller_identity.current.account_id}/monitoring/grafana/dashboards/ /var/lib/grafana/dashboards/ --recursive && aws s3 cp s3://artifacts-${data.aws_caller_identity.current.account_id}/monitoring/grafana/provisioning/ /etc/grafana/provisioning/ --recursive && chmod -R 777 /var/lib/grafana/dashboards/ /etc/grafana/provisioning/ && grafana-server --homepath=/usr/share/grafana"
      ]
      portMappings = [
        {
          containerPort = 3000
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "grafana_data"
          containerPath = "/var/lib/grafana"
          readOnly     = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])
}

# Task Definition para MariaDB
resource "aws_ecs_task_definition" "mariadb_stack" {
  family                   = "mariadb-stack"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  volume {
    name = "mysql_data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.monitoring_data.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.mysql_data.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "mysql_logs"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.monitoring_data.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.mysql_logs.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "mariadb"
      image     = "public.ecr.aws/docker/library/mariadb:10.6"
      cpu       = 1024
      memory    = 2048
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
          sourceVolume  = "mysql_data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        },
        {
          sourceVolume  = "mysql_logs"
          containerPath = "/var/log/mysql"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/mariadb-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mariadb"
        }
      }
    }
  ])
}

# Servicio ECS para API/Nginx
resource "aws_ecs_service" "api_service" {
  name                               = "api-service"
  cluster                           = aws_ecs_cluster.ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.api_stack.arn
  desired_count                     = 1
  health_check_grace_period_seconds = 120
  enable_execute_command           = true
  
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
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.security_group.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.api.arn
    container_name = "api"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_80.arn
    container_name   = "nginx"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana_tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }

    load_balancer {
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  depends_on = [
    aws_ecs_service.mariadb_service,
    aws_service_discovery_private_dns_namespace.monitoring,
    aws_lb_listener.http,
    aws_lb_listener.grafana_listener,
    aws_lb_listener.prometheus_listener
  ]
}

# Servicio ECS para MariaDB
resource "aws_ecs_service" "mariadb_service" {
  name                               = "mariadb-service"
  cluster                           = aws_ecs_cluster.ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.mariadb_stack.arn
  desired_count                     = 1  # Solo necesitamos una instancia de MariaDB
  enable_execute_command           = true
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 100  # No usamos SPOT para la base de datos
  }

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.security_group.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.mariadb.arn
    container_name = "mariadb"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_3306.arn
    container_name   = "mariadb"
    container_port   = 3306
  }
}