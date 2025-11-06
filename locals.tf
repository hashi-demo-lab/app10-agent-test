# Local Values
# Implements FR-012: Tag all resources appropriately for cost tracking and resource management

locals {
  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Application = "nginx-web-server"
    ManagedBy   = "Terraform"
    Feature     = "001-ec2-nginx-alb"
    Repository  = "app10-agent-test"
  }
}
