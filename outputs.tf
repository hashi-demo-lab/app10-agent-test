# Infrastructure Outputs
# Outputs will be populated in phases based on user stories
# Implements FR-014: Output ALB DNS endpoint for accessing the web application

# ==============================================================================
# Phase 2: Foundational Outputs (VPC and Networking)
# ==============================================================================

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of public subnets (for ALB placement)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets (for EC2 instance placement)"
  value       = module.vpc.private_subnets
}

# Gateway Outputs
output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.vpc.nat_public_ips
}

output "internet_gateway_id" {
  description = "ID of Internet Gateway"
  value       = module.vpc.igw_id
}

# ==============================================================================
# Phase 3: EC2 Instance Outputs (User Story 1)
# ==============================================================================

# EC2 Instance IDs
output "ec2_instance_ids" {
  description = "IDs of EC2 nginx instances"
  value       = module.ec2_nginx[*].id
}

# EC2 Private IP Addresses
output "ec2_private_ips" {
  description = "Private IP addresses of EC2 nginx instances"
  value       = module.ec2_nginx[*].private_ip
}

# EC2 Private DNS Names
output "ec2_private_dns" {
  description = "Private DNS names of EC2 nginx instances"
  value       = module.ec2_nginx[*].private_dns
}

# Security Group ID
output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_nginx.id
}

# AMI ID Used
output "ami_id_used" {
  description = "AMI ID used for EC2 instances"
  value       = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

# ==============================================================================
# Phase 4: Application Load Balancer Outputs (User Story 2)
# ==============================================================================

# ALB DNS Name (Primary Access Endpoint)
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application)"
  value       = module.alb.dns_name
}

# ALB ARN
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

# ALB Zone ID
output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

# Target Group ARNs
output "alb_target_group_arns" {
  description = "ARNs of the ALB target groups"
  value       = module.alb.target_groups
}

# ALB Security Group ID
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}
