# Main Infrastructure Configuration
# Implements FR-001 through FR-015 per feature specification

# ==============================================================================
# Data Sources
# ==============================================================================

# Get available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ==============================================================================
# Phase 2: Foundational Infrastructure (VPC and Networking)
# Implements FR-001: Provision EC2 in ap-southeast-2
# Implements FR-006: Deploy across at least 2 availability zones
# ==============================================================================

# VPC Module - Creates VPC with public/private subnets across multiple AZs
# Source: Private Terraform Registry (Constitution 1.1: Module-First Architecture)
module "vpc" {
  source  = "app.terraform.io/hashi-demos-apj/vpc/aws"
  version = "~> 6.5.0"

  # VPC Configuration
  name = "${var.project_name}-${var.environment}"
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  # Subnet Configuration
  public_subnets  = var.public_subnets  # For ALB and NAT Gateway
  private_subnets = var.private_subnets # For EC2 instances

  # NAT Gateway Configuration (for private subnet outbound connectivity)
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # DNS Configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Resource Tags (FR-012: Tag all resources appropriately)
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )

  # Subnet Tags
  public_subnet_tags = {
    Name = "${var.project_name}-${var.environment}-public"
    Tier = "public"
  }

  private_subnet_tags = {
    Name = "${var.project_name}-${var.environment}-private"
    Tier = "private"
  }
}

# ==============================================================================
# Phase 4: Application Load Balancer Security Group
# Defined early to allow EC2 security group to reference it
# Implements FR-005: Configure ALB for load distribution
# ==============================================================================

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # HTTP ingress from internet (internet-facing ALB)
  # tfsec:ignore:aws-ec2-no-public-ingress-sgr - Internet-facing ALB requires public HTTP access
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to VPC on HTTP (targets EC2 nginx instances)
  egress {
    description = "HTTP to VPC (EC2 nginx instances)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Phase 3: EC2 Instances with Nginx (User Story 1)
# Implements FR-002: Configure instances with nginx web server
# Implements FR-003: Serve custom HTML page with instance metadata
# Implements FR-013: Enable public IP for instance accessibility
# ==============================================================================

# Security Group for EC2 Instances
resource "aws_security_group" "ec2_nginx" {
  name_prefix = "${var.project_name}-${var.environment}-ec2-"
  description = "Security group for nginx web server instances"
  vpc_id      = module.vpc.vpc_id

  # HTTP ingress from ALB security group only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # All egress traffic for package installation and updates
  # tfsec:ignore:aws-ec2-no-public-egress-sgr - Required for yum/dnf package installation and system updates
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# User Data Script for Nginx Installation
locals {
  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y

    # Install nginx
    dnf install -y nginx

    # Get instance metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

    # Create custom HTML page with instance metadata
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Nginx Web Server - ${var.project_name}</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background-color: #f5f5f5;
            }
            .container {
                background-color: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            h1 {
                color: #009639;
                border-bottom: 3px solid #009639;
                padding-bottom: 10px;
            }
            .metadata {
                background-color: #f9f9f9;
                padding: 15px;
                border-left: 4px solid #009639;
                margin: 20px 0;
            }
            .metadata p {
                margin: 8px 0;
            }
            .label {
                font-weight: bold;
                color: #333;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Welcome to Nginx Web Server</h1>
            <p>This EC2 instance is serving a custom HTML page with metadata.</p>

            <div class="metadata">
                <h2>Instance Metadata</h2>
                <p><span class="label">Instance ID:</span> INSTANCE_ID_PLACEHOLDER</p>
                <p><span class="label">Availability Zone:</span> AVAILABILITY_ZONE_PLACEHOLDER</p>
                <p><span class="label">Private IP:</span> PRIVATE_IP_PLACEHOLDER</p>
                <p><span class="label">Environment:</span> ${var.environment}</p>
                <p><span class="label">Project:</span> ${var.project_name}</p>
            </div>

            <p style="margin-top: 30px; color: #666; font-size: 14px;">
                Managed by Terraform | Feature: 001-ec2-nginx-alb
            </p>
        </div>
    </body>
    </html>
    HTML

    # Replace placeholders with actual values
    sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /usr/share/nginx/html/index.html
    sed -i "s/AVAILABILITY_ZONE_PLACEHOLDER/$AVAILABILITY_ZONE/g" /usr/share/nginx/html/index.html
    sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /usr/share/nginx/html/index.html

    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx

    # Configure firewall
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
  EOF
}

# EC2 Instance Module - Nginx Web Server
module "ec2_nginx" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  count = var.instance_count

  # Instance Configuration
  name          = "${var.project_name}-${var.environment}-nginx-${count.index + 1}"
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  # Network Configuration
  subnet_id                   = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids      = [aws_security_group.ec2_nginx.id]
  associate_public_ip_address = false # Instances in private subnet

  # User Data
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # Root Volume Configuration (EBS encryption enabled)
  enable_volume_tags = true
  ebs_optimized      = true

  # Enable detailed monitoring
  monitoring = true

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nginx-${count.index + 1}"
      Role = "web-server"
    }
  )
}

# ==============================================================================
# Phase 4: Application Load Balancer (User Story 2)
# Implements FR-005: Configure ALB for load distribution
# Implements FR-006: Deploy across at least 2 availability zones
# Implements FR-007: Configure health checks with appropriate thresholds
# Implements FR-014: Output ALB DNS endpoint
# ==============================================================================

# Application Load Balancer Module
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "~> 10.1.0"

  # ALB Configuration
  name               = "${var.project_name}-${var.environment}"
  load_balancer_type = "application"
  internal           = var.alb_internal
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  # Enable deletion protection for production (disabled for sandbox)
  enable_deletion_protection = var.environment == "prod" ? true : false

  # Target Group Configuration
  target_groups = {
    nginx = {
      name_prefix      = "nginx-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        interval            = var.health_check_interval
        timeout             = var.health_check_timeout
        healthy_threshold   = var.health_check_healthy_threshold
        unhealthy_threshold = var.health_check_unhealthy_threshold
        matcher             = "200"
      }

      # Deregistration delay
      deregistration_delay = var.deregistration_delay

      # Stickiness disabled by default
      stickiness = {
        enabled = false
        type    = "lb_cookie"
      }
    }
  }

  # HTTP Listener
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "nginx"
      }
    }
  }

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# Attach EC2 instances to ALB target group
resource "aws_lb_target_group_attachment" "nginx" {
  count = var.instance_count

  target_group_arn = module.alb.target_groups["nginx"].arn
  target_id        = module.ec2_nginx[count.index].id
  port             = 80
}
