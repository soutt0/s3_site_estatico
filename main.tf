provider "aws" {
  region = "us-west-1"
}

# Criando a role para o Elastic Beanstalk
resource "aws_iam_role" "eb_role" {
  name = "eb-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

# Criando o bucket para armazenamento do Elastic Beanstalk
resource "aws_s3_bucket" "eb_bucket" {
  bucket = "my-app-terraform-bucket"
  acl    = "private"
}

# Aplicação Blue no Elastic Beanstalk
resource "aws_elastic_beanstalk_application" "blue_app" {
  name = "my-blue-app"
}

# Ambiente Blue no Elastic Beanstalk
resource "aws_elastic_beanstalk_environment" "blue_env" {
  name                = "blue-env"
  application         = aws_elastic_beanstalk_application.blue_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.4.4 running Node.js"
  version_label       = "v1"
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }
}

# Aplicação Green no Elastic Beanstalk
resource "aws_elastic_beanstalk_application" "green_app" {
  name = "my-green-app"
}

# Ambiente Green no Elastic Beanstalk
resource "aws_elastic_beanstalk_environment" "green_env" {
  name                = "green-env"
  application         = aws_elastic_beanstalk_application.green_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.4.4 running Node.js"
  version_label       = "v1"
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }
}

# Criando o Elastic Load Balancer (ELB)
resource "aws_lb" "main" {
  name               = "main-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-028876ea8672d3c3b"]
  subnets            = ["subnet-083ae6522e7dd6a38", "subnet-0f6d46efc48486c84"]

  enable_deletion_protection = false
}

# Target Group para Blue
resource "aws_lb_target_group" "blue_target_group" {
  name     = "blue-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0e8e0a31f8b1cd6b4"
}

# Target Group para Green
resource "aws_lb_target_group" "green_target_group" {
  name     = "green-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0e8e0a31f8b1cd6b4"
}

# Configuração de Listener para o Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}

# Configuração do Listener para Blue e Green
resource "aws_lb_listener_rule" "blue_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_target_group.arn
  }
  condition {
    field = "host-header"
    values = ["blue.myapp.com"]
  }
}

resource "aws_lb_listener_rule" "green_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_target_group.arn
  }
  condition {
    field = "host-header"
    values = ["green.myapp.com"]
  }
}
