# Application Load Balancer para tráfico HTTP
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "ecs-alb"
  }
}

# Network Load Balancer para MariaDB
resource "aws_lb" "mariadb_nlb" {
  name               = "mariadb-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "mariadb-nlb"
  }
}

# Target Group para Grafana
resource "aws_lb_target_group" "grafana_tg" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/login"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Target Group para Prometheus
resource "aws_lb_target_group" "prometheus_tg" {
  name        = "prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/metrics"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Listener para Grafana
resource "aws_lb_listener" "grafana_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn # Corregido para usar ecs_alb
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

# Listener para Prometheus
resource "aws_lb_listener" "prometheus_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn # Corregido para usar ecs_alb
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
  }
}


# Target Groups
resource "aws_lb_target_group" "ecs_tg_80" {
  name        = "ecs-tg-80"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "ecs_tg_3306" {
  name        = "ecs-tg-3306"
  port        = 3306
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "TCP"
  }
}

# Listeners
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_80.arn
  }
}

resource "aws_lb_listener" "mariadb" {
  load_balancer_arn = aws_lb.mariadb_nlb.arn
  port              = 3306
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_3306.arn
  }
}

# Auto Scaling Target for API Service
resource "aws_appautoscaling_target" "ecs_api_service" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.api_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Target for MariaDB Service
resource "aws_appautoscaling_target" "ecs_mariadb_service" {
  max_capacity       = 1  # MariaDB no debería escalar horizontalmente
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.mariadb_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policies for API Service
resource "aws_appautoscaling_policy" "ecs_cpu_policy_api" {
  name               = "cpu-autoscaling-api"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_api_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_api_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_api_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80.0
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy_api" {
  name               = "memory-autoscaling-api"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_api_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_api_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_api_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

resource "aws_appautoscaling_policy" "ecs_alb_request_count_policy" {
  name               = "alb-request-count-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_api_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_api_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_api_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label        = "${aws_lb.ecs_alb.arn_suffix}/${aws_lb_target_group.ecs_tg_80.arn_suffix}"
    }
    target_value = 1000.0
  }
}