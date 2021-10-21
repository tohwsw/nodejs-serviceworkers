terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36"
    }
  }
}

variable "ecs_cluster_arn" {
  type        = string
  default     = "INPUT YOUR VALUE"
}

variable "ecs_task_role" {
  type        = string
  default     = "INPUT YOUR VALUE"
}

variable "ecr_image_id" {
  type        = string
  default     = "INPUT YOUR VALUE"
}



provider "aws" {
  region = "ap-southeast-1"
  profile = "default"
}

resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default vpc"
  }
}

data "aws_subnet_ids" "default_vpc_subnets" {
  vpc_id = aws_default_vpc.default_vpc.id

}

resource "aws_security_group" "cdn_nodejs_lb_sg" {
  name        = "allow_http"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress = [
    {
      description      = "HTTP traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = false
    }
  ]

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb" "cdn_nodejs_lb" {
  name               = "cdn-nodejs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.cdn_nodejs_lb_sg.id]
  subnets            = data.aws_subnet_ids.default_vpc_subnets.ids

  depends_on = [aws_security_group.cdn_nodejs_lb_sg]
}

resource "aws_lb_target_group" "cdn_nodejs_tg" {
  name     = "cdn-nodejs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default_vpc.id
  target_type = "ip"
  health_check {
    path = "/sw/hello"
  }
}

resource "aws_lb_listener" "cdn_nodejs_listener" {
  load_balancer_arn = aws_lb.cdn_nodejs_lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.cdn_nodejs_tg.id
    type             = "forward"
  }
}

resource "aws_ecs_task_definition" "cdn_nodejs_task_def" {
  family                   = "cdn-nodejs-app"
  execution_role_arn         = var.ecs_task_role
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = <<DEFINITION
[
  {
    "image": "${var.ecr_image_id}",
    "cpu": 256,
    "memory": 512,
    "name": "cdn-nodejs-app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ]
  }
]
DEFINITION
}

resource "aws_security_group" "cdn_nodejs_task_sg" {
  name        = "example-task-security-group"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [aws_security_group.cdn_nodejs_lb_sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_ecs_service" "cdn_nodejs_service" {
  name            = "cdn-nodejs-service"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.cdn_nodejs_task_def.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.cdn_nodejs_task_sg.id]
    subnets         = data.aws_subnet_ids.default_vpc_subnets.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cdn_nodejs_tg.id
    container_name   = "cdn-nodejs-app"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.cdn_nodejs_listener]
}



resource "aws_cloudfront_distribution" "cdn_nodejs_cf" {
  enabled          = true

  origin {
    domain_name = aws_lb.cdn_nodejs_lb.dns_name
    origin_id   = aws_lb.cdn_nodejs_lb.name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }


  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.cdn_nodejs_lb.name

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


output "cdn_domain_name" {
  value = aws_cloudfront_distribution.cdn_nodejs_cf.domain_name
}
