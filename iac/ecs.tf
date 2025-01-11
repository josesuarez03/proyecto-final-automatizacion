resource "aws_ecs_cluster" "ecs_cluster" {
 name = "my-ecs-cluster"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "test1"

 auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

   managed_scaling {
     maximum_scaling_step_size = 1000
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 50
   }
 }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
 cluster_name = aws_ecs_cluster.ecs_cluster.name

 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

 default_capacity_provider_strategy {
   base              = 1
   weight            = 100
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
 }
}

resource "aws_ecs_service" "ecs_service" {
 name            = "my-ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.monitoring_stack.arn
 desired_count   = 2

 network_configuration {
   subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
   security_groups = [aws_security_group.security_group.id]
 }

 force_new_deployment = true
 placement_constraints {
   type = "distinctInstance"
 }

 triggers = {
   redeployment = timestamp()
 }

 capacity_provider_strategy {
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
   weight            = 100
 }

 load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_80.arn
    container_name   = "nginx"
    container_port   = 80
  }

  # Grafana
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_3000.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  # Kibana
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_5601.arn
    container_name   = "kibana"
    container_port   = 5601
  }

  # MariaDB
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_3306.arn
    container_name   = "mariadb"
    container_port   = 3306
  }

  depends_on = [
    aws_autoscaling_group.ecs_asg,
    aws_lb_listener.http,
    aws_lb_listener.grafana,
    aws_lb_listener.kibana,
    aws_lb_listener.mariadb
  ]
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
  requires_compatibilities = ["EC2"]
  network_mode            = "awsvpc"
  cpu                     = "4096"  # 4 vCPU for t3.large
  memory                  = "8192"  # 8GB for t3.large
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  # Configuración de volúmenes
  volume {
    name = "efs-monitoring"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.monitoring_data.id
      root_directory = "/"
    }
  }

   volume {
    name = "prometheus_config"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/prometheus"
        o      = "bind"
      }
    }
  }

  volume {
    name = "grafana_config"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/grafana"
        o      = "bind"
      }
    }
  }

  volume {
    name = "elasticsearch_config"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/elk/elasticsearch"
        o      = "bind"
      }
    }
  }

  volume {
    name = "logstash_config"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/elk/logstash"
        o      = "bind"
      }
    }
  }

  volume {
    name = "kibana_config"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/elk/kibanah"
        o      = "bind"
      }
    }
  }

   volume {
    name = "nginx-logs"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/nginx/logs"
        o      = "bind"
      }
    }
  }

  volume {
    name = "mysql-logs"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
      driver_opts = {
        type   = "none"
        device = "/opt/monitoring/mysql/logs"
        o      = "bind"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image = "${data.aws_ecr_repository.docker.repository_url}:api"
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
      image = "${data.aws_ecr_repository.docker.repository_url}:nginx"
      cpu       = 128  # Reduced CPU
      memory    = 256  # Reduced memory
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
      cpu       = 64  # Reduced CPU
      memory    = 128  # Reduced memory
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
    },
    {
      name      = "mariadb"
      image     = "mariadb:10.6"
      cpu       = 512
      memory    = 1024
      essential = true
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
    },
    {
      name      = "mariadb-exporter"
      image     = "prom/mysqld-exporter:latest"
      cpu       = 64  # Reduced CPU
      memory    = 128  # Reduced memory
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
    },
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      cpu       = 128  # Reduced CPU
      memory    = 256  # Reduced memory
      essential = true
      portMappings = [
        {
          containerPort = 9090
          hostPort     = 9090
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus_config"
          containerPath = "/etc/prometheus"
          readOnly     = true
        }
      ]
    },
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      cpu       = 128  # Reduced CPU
      memory    = 256  # Reduced memory
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort     = 3000
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "grafana_config"
          containerPath = "/etc/grafana"
          readOnly     = true
        },
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/var/lib/grafana"
          readOnly     = false
        }
      ]
    },
    {
      name      = "elasticsearch"
      image     = "elasticsearch:7.9.1"
      cpu       = 512  # Reduced CPU
      memory    = 1024  # Reduced memory
      essential = true
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
      environment = [
        { name = "discovery.type", value = "single-node" },
        { name = "http.host", value = "0.0.0.0" },
        { name = "transport.host", value = "0.0.0.0" },
        { name = "xpack.security.enabled", value = "false" },
        { name = "xpack.monitoring.enabled", value = "false" },
        { name = "cluster.name", value = "elasticsearch" },
        { name = "bootstrap.memory_lock", value = "true" }
      ]
      mountPoints = [
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/usr/share/elasticsearch/data"
          readOnly     = false
        },
        {
          sourceVolume  = "elasticsearch_config"
          containerPath = "/usr/share/elasticsearch/config"
          readOnly     = true
        }
      ]
      ulimits = [
        {
          name      = "memlock"
          softLimit = -1
          hardLimit = -1
        }
      ]
    },
    {
      name      = "logstash"
      image     = "logstash:7.9.1"
      cpu       = 128  # Reduced CPU
      memory    = 256  # Reduced memory
      essential = true
      portMappings = [
        {
          containerPort = 5044
          hostPort     = 5044
          protocol     = "tcp"
        },
        {
          containerPort = 9600
          hostPort     = 9600
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "logstash_config"
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
    },
    {
      name      = "kibana"
      image     = "kibana:7.9.1"
      cpu       = 128  # Reduced CPU
      memory    = 256  # Reduced memory
      essential = true
      portMappings = [
        {
          containerPort = 5601
          hostPort     = 5601
          protocol     = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "kibana_config"
          containerPath = "/usr/share/kibana/config"
          readOnly     = true
        },
        {
          sourceVolume  = "efs-monitoring"
          containerPath = "/usr/share/kibana/data"
          readOnly     = false
        }
      ]
    }
  ])

  tags = {
    Name = "MonitoringStack"
  }
}

