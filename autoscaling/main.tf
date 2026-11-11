
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Existing default VPC and two Availability Zones
data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

data "aws_subnet" "default" {
  count = 2

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.available.names[count.index]]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Amazon Linux 2023 image
data "aws_ssm_parameter" "linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security group for the public ALB
resource "aws_security_group" "alb" {
  name_prefix = "JennyOma-alb-"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "JennyOma-Week2-ALB-SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Security group for the EC2 web servers
resource "aws_security_group" "web" {
  name_prefix = "JennyOma-web-"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "JennyOma-Week2-Web-SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Allows package installation during startup
resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Two EC2 instances in separate Availability Zones

# Template used by Auto Scaling to launch EC2 servers
resource "aws_launch_template" "web" {
  name_prefix   = "JennyOma-Week2-ASG-"
  image_id      = data.aws_ssm_parameter.linux.value
  instance_type = "t3.micro"

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <h1>JennyOma Auto Scaling Lab</h1>
    <p>This EC2 instance was launched by Auto Scaling.</p>
    HTML

    systemctl enable nginx
    systemctl start nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "JennyOma-Week2-ASG-Web"
    }
  }
}


# Application Load Balancer
resource "aws_lb" "web" {
  name               = "JennyOma-Week2-ALB"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    for subnet in data.aws_subnet.default : subnet.id
  ]
}

# ALB target group and health checks
resource "aws_lb_target_group" "web" {
  name        = "JennyOma-Week2-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Register both EC2 servers with the target group

# Maintain EC2 capacity automatically
resource "aws_autoscaling_group" "web" {
  name = "JennyOma-Week2-ASG"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = [
    for subnet in data.aws_subnet.default : subnet.id
  ]

  target_group_arns = [
    aws_lb_target_group.web.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}

# Listen for HTTP requests and forward to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Automatically adjust EC2 capacity based on CPU usage
resource "aws_autoscaling_policy" "cpu" {
  name                   = "JennyOma-Week2-CPU-Scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

