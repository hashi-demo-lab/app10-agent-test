# AWS Provider Configuration
# Implements FR-001: Provision EC2 in ap-southeast-2
# Implements Constitution Section 3.1: Credential Management (dynamic credentials via workspace variable sets)

provider "aws" {
  region = var.region

  # Dynamic credentials provided automatically via HCP Terraform workspace variable sets
  # No static credentials configured here (Constitution 3.1)

  default_tags {
    tags = local.common_tags
  }
}
