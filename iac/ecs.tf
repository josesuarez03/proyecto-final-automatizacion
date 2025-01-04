resource "aws_ecs_cluster" "main" {
  name = "my-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_appautoscaling_target" "app_service_scaling" {
  max_capacity       = 5
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_up_policy" {
  name               = "scale-up-policy"
  resource_id        = aws_appautoscaling_target.app_service_scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.app_service_scaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_service_scaling.service_namespace
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment = 1
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_appautoscaling_policy" "scale_down_policy" {
  name               = "scale-down-policy"
  resource_id        = aws_appautoscaling_target.app_service_scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.app_service_scaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_service_scaling.service_namespace
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment = -1
      metric_interval_upper_bound = 0
    }
  }
}

resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 2

  force_new_deployment = true
  
  placement_constraints {
    type = "distinctInstance"
  }
  
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent = 200

  launch_type = "EC2"
  
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.security_group.id]
    assign_public_ip = false
  }

  deployment_controller {
    type = "ECS"
  }

  depends_on = [aws_autoscaling_group.ecs_asg]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

data "aws_ecr_repository" "docker" {
  name = "docker"
}

resource "aws_ecs_task_definition" "app_task" {
  family                = "app-task"
  network_mode         = "awsvpc"
  execution_role_arn   = aws_iam_role.ecs_execution_role.arn
  task_role_arn        = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${data.aws_ecr_repository.docker.repository_url}:api"
      cpu = 512
      memory = 1024
      environment = [
        { name = "DB_HOST", value = "db" },
        { name = "DB_USER", value = "admin" },
        { name = "DB_PASSWORD", value = "1234" },
        { name = "DB_NAME", value = "task_app" }
      ]
      dependsOn = [{ containerName = "db", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      name  = "nginx"
      image = "${data.aws_ecr_repository.docker.repository_url}:nginx"
      cpu = 256
      memory = 512
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      dependsOn = [{ containerName = "api", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    },
    {
      name  = "nginx_exporter"
      image = "nginx/nginx-prometheus-exporter:latest"
      cpu = 64
      memory = 128
      portMappings = [
        {
          containerPort = 9113
          hostPort      = 9113
        }
      ]
      environment = [
        { name = "NGINX_STATUS_URL", value = "http://nginx/metrics" }
      ]
      dependsOn = [{ containerName = "nginx", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx-exporter"
        }
      }
    },
    {
      name  = "db"
      image = "mariadb:10.6"
      cpu = 512
      memory = 1024
      environment = [
        { name = "MARIADB_ROOT_PASSWORD", value = "root" },
        { name = "MYSQL_PASSWORD", value = "1234" },
        { name = "MYSQL_DATABASE", value = "task_app" },
        { name = "MYSQL_USER", value = "admin" }
      ]
      portMappings = [
        {
          containerPort = 3306
          hostPort      = 3306
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "db_data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "db"
        }
      }
    },
    {
      name  = "mariadb_exporter"
      image = "prom/mysqld-exporter:latest"
      cpu = 64
      memory = 128
      environment = [
        { name = "DATA_SOURCE_NAME", value = "admin:1234@tcp(db:3306)/task_app" }
      ]
      portMappings = [
        {
          containerPort = 9104
          hostPort      = 9104
        }
      ]
      dependsOn = [{ containerName = "db", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mariadb-exporter"
        }
      }
    },
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"
      cpu = 512
      memory = 1024
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus_data"
          containerPath = "/prometheus"
          readOnly      = false
        },
        {
          sourceVolume  = "prometheus_config"
          containerPath = "/etc/prometheus"
          readOnly      = true
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    },
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      cpu = 256
      memory = 512
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "grafana_data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        },
        {
          sourceVolume  = "grafana_config"
          containerPath = "/etc/grafana"
          readOnly      = true
        }
      ]
      dependsOn = [{ containerName = "prometheus", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    },
    {
      name  = "elasticsearch"
      image = "elasticsearch:7.9.1"
      cpu = 512
      memory = 1024
      portMappings = [
        {
          containerPort = 9200
          hostPort      = 9200
        },
        {
          containerPort = 9300
          hostPort      = 9300
        }
      ]
      environment = [
        { name = "discovery.type", value = "single-node" },
        { name = "http.host", value = "0.0.0.0" },
        { name = "transport.host", value = "0.0.0.0" },
        { name = "xpack.security.enabled", value = "false" },
        { name = "xpack.monitoring.enabled", value = "false" },
        { name = "cluster.name", value = "elasticsearch" },
        { name = "bootstrap.memory_lock", value = "false" },
        { name = "ES_JAVA_OPTS", value = "-Xms512m -Xmx512m" }
      ]
      mountPoints = [
        {
          sourceVolume  = "test_data"
          containerPath = "/usr/share/elasticsearch/data"
          readOnly      = false
        },
        {
          sourceVolume  = "elasticsearch_config"
          containerPath = "/usr/share/elasticsearch/config"
          readOnly      = true
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "elasticsearch"
        }
      }
    },
    {
      name  = "logstash"
      image = "logstash:7.9.1"
      cpu = 256
      memory = 512
      portMappings = [
        {
          containerPort = 5044
          hostPort      = 5044
        },
        {
          containerPort = 9600
          hostPort      = 9600
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "ls_data"
          containerPath = "/usr/share/logstash/data"
          readOnly      = false
        },
        {
          sourceVolume  = "logstash_config"
          containerPath = "/usr/share/logstash/config"
          readOnly      = true
        }
      ]
      dependsOn = [{ containerName = "elasticsearch", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "logstash"
        }
      }
    },
    {
      name  = "kibana"
      image = "kibana:7.9.1"
      cpu = 256
      memory = 512
      portMappings = [
        {
          containerPort = 5601
          hostPort      = 5601
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "kb_data"
          containerPath = "/usr/share/kibana/data"
          readOnly      = false
        },
        {
          sourceVolume  = "kibana_config"
          containerPath = "/usr/share/kibana/config"
          readOnly      = true
        }
      ]
      dependsOn = [{ containerName = "elasticsearch", condition = "START" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "kibana"
        }
      }
    }
  ])

  volume {
    name = "db_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.db_data.id
    }
  }

  volume {
    name = "grafana_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.grafana_data.id
    }
  }

  volume {
    name = "prometheus_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus_data.id
    }
  }

  volume {
    name = "test_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.test_data.id
    }
  }

  volume {
    name = "ls_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.ls_data.id
    }
  }

  volume {
    name = "kb_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.kb_data.id
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
}

resource "aws_efs_file_system" "db_data" {
  creation_token = "db-data"
  encrypted      = true
  tags = {
    Name = "db-data"
  }
}

resource "aws_efs_file_system" "grafana_data" {
  creation_token = "grafana-data"
  encrypted      = true
  tags = {
    Name = "grafana-data"
  }
}

resource "aws_efs_file_system" "prometheus_data" {
  creation_token = "prometheus-data"
  encrypted      = true
  tags = {
    Name = "prometheus-data"
  }
}

resource "aws_efs_file_system" "test_data" {
  creation_token = "test-data"
  encrypted      = true
  tags = {
    Name = "test-data"
  }
}

resource "aws_efs_file_system" "ls_data" {
  creation_token = "ls-data"
  encrypted      = true
  tags = {
    Name = "ls-data"
  }
}

resource "aws_efs_file_system" "kb_data" {
  creation_token = "kb-data"
  encrypted      = true
  tags = {
    Name = "kb-data"
  }
}

resource "aws_efs_mount_target" "db_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.db_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "grafana_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.grafana_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "prometheus_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.prometheus_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "test_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.test_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "ls_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.ls_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_efs_mount_target" "kb_data" {
  count           = 2
  file_system_id  = aws_efs_file_system.kb_data.id
  subnet_id       = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  security_groups = [aws_security_group.security_group.id]
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/app-logs"
  retention_in_days = 30
}
