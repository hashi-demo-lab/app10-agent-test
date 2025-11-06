# Terraform and Provider Version Constraints
# Implements Constitution Section 6.2: Dependency Management

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19"
    }
  }
}
