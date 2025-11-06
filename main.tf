# Main Infrastructure Configuration
# Implements FR-001 through FR-015 per feature specification

# ==============================================================================
# Data Sources
# ==============================================================================

# Get available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
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
