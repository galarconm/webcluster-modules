resource "aws_launch_template" "example" {
    image_id = "ami-020cba7c55df1f615"
    #security_group_names = [ aws_security_group.http.id ]
    instance_type = var.instance_type

    network_interfaces {
      associate_public_ip_address = true
      security_groups = [aws_security_group.http.id]
    }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port

  }))
    
    
    lifecycle {
      create_before_destroy = true
    }
  
}

resource "aws_security_group" "http" {
    description = "Allow HTTP trafic from the outside"
    name = "${var.cluster_name}-Allow_HTTP"

    ingress {
        from_port = var.server_port #8080
        to_port = var.server_port #8080
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
  
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id] 
    } 
}


resource "aws_autoscaling_group" "example" {
    #launch_configuration = aws_launch_configuration.example.name
    launch_template {
      id = aws_launch_template.example.id
      version = "$Latest"
    }
    vpc_zone_identifier = data.aws_subnets.default.ids
    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    min_size = var.min_size
    max_size = var.max_size

    tag {
      key = "Name"
      value = "${var.cluster_name}-asg"
      propagate_at_launch = true
    }
  
}

resource "aws_alb" "cloud_lb" {
    name = "${var.cluster_name}-alb"
    load_balancer_type = "application"
    internal =  false # scheme -> "internet-facing"
    subnets = data.aws_subnets.default.ids
    security_groups = [ aws_security_group.alb.id ]
}

resource "aws_alb_listener" "http" {
    load_balancer_arn = aws_alb.cloud_lb.arn
    port = local.http_port
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
      }
    }
  
}

resource "aws_security_group" "alb" {
    name =  "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "Allow_HTTP_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id
  
  from_port = local.http_port
  to_port = local.http_port
  protocol = local.any_port
  cidr_blocks =local.all_ips
   
}

  
resource "aws_security_group_rule" "Allow_HTTP_outbound" {
  type = "egress"
  security_group_id = aws_security_group.alb.id

  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = local.all_ips  
  
}

resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
  
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_alb_listener.http.arn
    priority = 100

    condition {
      path_pattern {
        values = ["*"]
      }
    }

    action {
      type = "forward"
      target_group_arn = aws_lb_target_group.asg.arn
    }
  
}

# read the remote state of the database module
# This allows us to access the outputs of the database module, such as the address and port
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-1"
  }
}

locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
}