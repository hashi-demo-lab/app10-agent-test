# Input Variable Declarations
# Variables will be populated in phases based on user stories
# Implements Constitution Section 3.4: Variable Management

# ==============================================================================
# Phase 2: Foundational Variables (Core Networking)
# ==============================================================================

# Region Configuration
variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., ap-southeast-2)."
  }
}

# Availability Zones
variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability."
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# Public Subnets (for ALB and NAT Gateway)
variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "At least 2 public subnets required for multi-AZ deployment."
  }
}

# Private Subnets (for EC2 instances)
variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "At least 2 private subnets required for multi-AZ deployment."
  }
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet outbound connectivity"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization) vs one per AZ (high availability)"
  type        = bool
  default     = true
}

# Environment and Project Metadata
variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "sandbox"

  validation {
    condition     = contains(["sandbox", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: sandbox, dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource tagging and naming"
  type        = string
  default     = "nginx-web-server"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# ==============================================================================
# Phase 3: EC2 Instance Variables (User Story 1)
# ==============================================================================

# EC2 Instance Type
variable "instance_type" {
  description = "EC2 instance type for nginx web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t3.micro, t3.small)."
  }
}

# AMI ID (optional - data source used if not provided)
variable "ami_id" {
  description = "AMI ID for EC2 instances (defaults to latest Amazon Linux 2023 if not specified)"
  type        = string
  default     = ""
}

# SSH Key Name
variable "key_name" {
  description = "EC2 key pair name for SSH access (optional)"
  type        = string
  default     = ""
}

# Instance Count
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
