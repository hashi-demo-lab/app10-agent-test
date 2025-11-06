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
