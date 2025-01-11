resource "aws_key_pair" "ecs_key_pair" {
  key_name   = "ec2ecsglog"
  public_key = file("${path.module}/ec2ecsglog.pub")
}

resource "aws_launch_template" "ecs_lt" {
 name_prefix   = "ecs-template"
 image_id      = "ami-01f5f2e96f603b15b"
 instance_type = "t3.large"

 key_name               = "ec2ecsglog"
 vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

 block_device_mappings {
   device_name = "/dev/xvda"
   ebs {
     volume_size = 30
     volume_type = "gp2"
   }
 }

 tag_specifications {
   resource_type = "instance"
   tags = {
     Name = "ecs-instance"
   }
 }

 user_data = filebase64("${path.module}/ecs.sh")
}

resource "aws_autoscaling_group" "ecs_asg" {
 vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
 desired_capacity    = 2
 max_size            = 3
 min_size            = 1

 launch_template {
   id      = aws_launch_template.ecs_lt.id
   version = "$Latest"
 }

 tag {
   key                 = "AmazonECSManaged"
   value               = true
   propagate_at_launch = true
 }
}

# Application Load Balancer para tráfico HTTP
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"  # Tipo application para HTTP
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
  load_balancer_type = "network"  # Tipo network para TCP
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "mariadb-nlb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_80.arn
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_3000.arn
  }
}

resource "aws_lb_listener" "kibana" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 5601
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_5601.arn
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

resource "aws_lb_target_group" "ecs_tg_3000" {
  name        = "ecs-tg-3000"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/api/health"
  }
}

resource "aws_lb_target_group" "ecs_tg_5601" {
  name        = "ecs-tg-5601"
  port        = 5601
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/api/status"
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