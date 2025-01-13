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

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_services_stack" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.services_stack.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policies
resource "aws_appautoscaling_policy" "ecs_cpu_policy_services" {
  name               = "cpu-autoscaling-services"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_services_stack.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services_stack.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services_stack.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80.0
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy_services" {
  name               = "memory-autoscaling-services"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_services_stack.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services_stack.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services_stack.service_namespace

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
  resource_id        = aws_appautoscaling_target.ecs_services_stack.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services_stack.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services_stack.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label        = "${aws_lb.ecs_alb.arn_suffix}/${aws_lb_target_group.ecs_tg_80.arn_suffix}"
    }
    target_value = 1000.0
  }
}