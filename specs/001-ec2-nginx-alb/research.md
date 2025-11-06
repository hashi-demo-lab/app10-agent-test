# Research: EC2 Nginx Web Server with Application Load Balancer

**Feature**: 001-ec2-nginx-alb
**Date**: 2025-11-06
**Research Phase**: Phase 0

## Executive Summary

This research phase validates that all required infrastructure components are available in the hashi-demos-apj private Terraform registry and establishes best practices for secure deployment of EC2-based nginx web servers with Application Load Balancer in AWS ap-southeast-2.

**Key Finding**: All required modules exist in private registry - no custom resource development needed.

---

## 1. Module Selection Decisions

### 1.1 VPC Module

**Decision**: Use `hashi-demos-apj/vpc/aws` version `~> 6.5`

**Rationale**:
- Comprehensive VPC management with multi-AZ support
- Built-in NAT Gateway and Internet Gateway configuration
- Supports both public and private subnets required for ALB (public) and EC2 (private) placement
- VPC Flow Logs support for security monitoring
- Well-maintained with recent updates (2025-10-26)

**Key Capabilities**:
- Creates VPC with configurable CIDR blocks
- Manages public/private/database subnet tiers
- NAT Gateway support for private subnet internet access
- Internet Gateway for public ALB connectivity
- Network ACL configuration

**Source**: `app.terraform.io/hashi-demos-apj/vpc/aws`

### 1.2 EC2 Instance Module

**Decision**: Use `hashi-demos-apj/ec2-instance/aws` version `~> 6.1`

**Rationale**:
- Supports user_data for nginx installation automation
- IAM instance profile creation for Systems Manager access
- IMDSv2 enforcement for enhanced security
- Security group creation and management
- Integrates with Auto Scaling Group launch templates

**Key Capabilities**:
- Single or multiple instance deployment
- Custom AMI selection (will use Amazon Linux 2023)
- User data script support for nginx bootstrap
- IAM instance profile for secure credential management
- Security group creation with customizable rules

**Source**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws`

**Alternative Considered**: Direct EC2 resource declaration
**Rejected Because**: Violates constitution requirement for module-first architecture; module provides better security defaults and IMDSv2 enforcement

### 1.3 Application Load Balancer Module

**Decision**: Use `hashi-demos-apj/alb/aws` version `~> 10.1`

**Rationale**:
- Comprehensive ALB management with target group integration
- Built-in security group creation and management
- HTTP listener support with optional HTTPS upgrade path
- Health check configuration for target groups
- Access logging capabilities

**Key Capabilities**:
- Application Load Balancer (ALB) creation
- Target group management with health checks
- HTTP/HTTPS listeners with customizable rules
- Security group integration
- Multi-AZ deployment support
- DNS name output for access

**Source**: `app.terraform.io/hashi-demos-apj/alb/aws`

### 1.4 Auto Scaling Group Module

**Decision**: Use `hashi-demos-apj/autoscaling/aws` version `~> 9.0`

**Rationale**:
- Launch template creation with user data support
- Target tracking scaling policies for CPU-based scaling
- ALB target group integration
- IAM instance profile support
- Instance refresh for rolling updates

**Key Capabilities**:
- Auto Scaling Group with configurable min/max/desired capacity
- Launch template with AMI, instance type, security groups
- Scaling policies (target tracking recommended)
- Health check integration with ALB
- Multi-AZ instance distribution

**Source**: `app.terraform.io/hashi-demos-apj/autoscaling/aws`

**Alternative Considered**: Manual launch template + ASG resources
**Rejected Because**: Module provides integrated lifecycle management and better default configurations

---

## 2. AWS Provider and Regional Availability

### 2.1 Provider Version

**Decision**: AWS Provider version `~> 6.19`

**Rationale**:
- Latest stable version (6.19.0)
- Includes all required resource types
- Pessimistic constraint allows patch updates while preventing breaking changes
- Well-tested and production-ready

**Configuration**:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19"
    }
  }
}
```

### 2.2 Regional Availability (ap-southeast-2)

**Validation Result**: All services AVAILABLE ✅

Confirmed availability in ap-southeast-2 (Sydney):
- ✅ EC2 (all instance operations)
- ✅ Elastic Load Balancing v2 (ALB)
- ✅ Auto Scaling
- ✅ VPC and Networking

**Availability Zones**: Will use ap-southeast-2a and ap-southeast-2b for multi-AZ deployment

---

## 3. Instance Type Selection

### 3.1 Recommended Instance Type

**Decision**: Start with `t3.micro` for cost optimization, scale to `t3.small` for production

**Rationale**:
- **t3.micro** (2 vCPU, 1 GiB RAM):
  - Most cost-effective for development/testing
  - Suitable for nginx serving static content
  - Burstable performance handles traffic spikes
  - Baseline 10% CPU with burst credits

- **t3.small** (2 vCPU, 2 GiB RAM):
  - Recommended for production workloads
  - Better memory headroom for nginx
  - Baseline 20% CPU performance
  - Good balance of cost and performance

**Production Upgrade Path**:
- Light traffic: `t3.small`
- Medium traffic: `t3.medium` (2 vCPU, 4 GiB)
- High traffic: `c7i.large` (2 vCPU, 4 GiB, compute-optimized)

**Processor Architecture**:
- Primary: x86_64 (Intel)
- Alternative: ARM64 (Graviton t4g.* instances) for 40% cost savings if compatible

### 3.2 AMI Selection

**Decision**: Amazon Linux 2023 (latest)

**Rationale**:
- Modern systemd-based OS
- Built-in AWS integration (CloudWatch, Systems Manager)
- Long-term support (5 years)
- Optimized for EC2 performance
- Regular security updates
- nginx available via package manager

**AMI Source**: Use AWS Systems Manager Parameter Store for latest AMI ID
- Parameter: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`

---

## 4. Security Architecture

### 4.1 Network Architecture

**Decision**: Three-tier security model

```
Internet
    ↓
┌─────────────────────────────────┐
│  Public Subnets (2 AZs)        │
│  - Application Load Balancer   │
│  - NAT Gateways                │
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│  Private Subnets (2 AZs)       │
│  - EC2 Instances (nginx)        │
│  - Auto Scaling Group           │
└─────────────────────────────────┘
```

**Rationale**:
- EC2 instances in private subnets (no public IPs) - principle of least privilege
- ALB in public subnets with internet access
- NAT Gateways for EC2 outbound connectivity (package updates, monitoring)
- Multi-AZ deployment for high availability

### 4.2 Security Group Strategy

**Decision**: Three security groups with minimal privileges

**1. ALB Security Group**:
```hcl
Ingress:
  - Port 80 (HTTP) from 0.0.0.0/0
Egress:
  - Port 80 (HTTP) to EC2 Security Group only
```

**2. EC2 Security Group**:
```hcl
Ingress:
  - Port 80 (HTTP) from ALB Security Group only
Egress:
  - Port 443 (HTTPS) to 0.0.0.0/0 (package updates)
  - Port 80 (HTTP) to 0.0.0.0/0 (package repos)
```

**3. VPC Endpoint Security Group** (optional for Systems Manager):
```hcl
Ingress:
  - Port 443 (HTTPS) from VPC CIDR
```

**Rationale**:
- Least privilege - EC2 instances only accept traffic from ALB
- No direct internet access to EC2 instances
- Outbound restricted to necessary services
- Security group chaining prevents unauthorized access

### 4.3 IAM Strategy

**Decision**: EC2 instance profile with Systems Manager access

**Required Permissions**:
- **AmazonSSMManagedInstanceCore** (managed policy)
  - Enables Systems Manager Session Manager
  - CloudWatch Logs integration
  - Eliminates need for SSH bastions

**Custom Policy** (optional for CloudWatch):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Rationale**:
- No hardcoded credentials (dynamic credentials via instance profile)
- Systems Manager Session Manager for secure instance access
- CloudWatch integration for monitoring
- Follows AWS IAM best practices

### 4.4 Critical Security Requirements

**Must Implement**:
1. ✅ **IMDSv2 Enforcement**: Prevent credential theft attacks
2. ✅ **Private Subnets for EC2**: No public IP addresses on instances
3. ✅ **Security Group Chaining**: EC2 only accepts traffic from ALB
4. ✅ **EBS Encryption**: Enable default encryption
5. ✅ **VPC Flow Logs**: Enable for security monitoring
6. ✅ **Systems Manager Session Manager**: No SSH keys or bastions

**Security Documentation Reference**:
See `/workspace/ec2-alb-nginx-security-analysis.md` for comprehensive security guidance

---

## 5. Load Balancer Configuration

### 5.1 Health Check Configuration

**Decision**: HTTP health checks with dedicated endpoint

**Configuration**:
```hcl
health_check {
  enabled             = true
  healthy_threshold   = 2
  unhealthy_threshold = 3
  timeout             = 5
  interval            = 30
  path                = "/health"
  protocol            = "HTTP"
  matcher             = "200"
}
```

**Rationale**:
- 30-second interval balances cost and failure detection speed
- 2 successful checks confirm instance health
- 3 failures prevent false positives from transient issues
- Dedicated `/health` endpoint doesn't log to reduce noise
- 5-second timeout sufficient for nginx response

**Nginx Health Endpoint**:
```nginx
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```

### 5.2 Deregistration Delay

**Decision**: 30 seconds

**Rationale**:
- Allows in-flight requests to complete
- Shorter than default (300s) suitable for nginx workloads
- Balances graceful shutdown with rapid scaling

### 5.3 ALB Listener Configuration

**Decision**: HTTP listener on port 80 (initial deployment)

**Future Enhancement**: HTTPS listener with ACM certificate
- HTTP to HTTPS redirect
- TLS 1.2+ with AWS recommended security policy
- ACM certificate management

**Rationale**:
- Specification requires HTTP-only initial deployment
- HTTPS deferred to future phase per FR-015
- ALB positioned for easy HTTPS upgrade

---

## 6. Auto Scaling Configuration

### 6.1 Capacity Settings

**Decision**:
```hcl
min_size         = 2
max_size         = 4
desired_capacity = 2
```

**Rationale**:
- Minimum 2 instances across 2 AZs for high availability
- Maximum 4 instances provides 2x scaling headroom
- Initial desired capacity = minimum for cost optimization
- Can adjust based on actual traffic patterns

### 6.2 Scaling Policy

**Decision**: Target Tracking based on CPU utilization

**Configuration**:
```hcl
target_tracking_configuration {
  predefined_metric_specification {
    predefined_metric_type = "ASGAverageCPUUtilization"
  }
  target_value = 50.0
  estimated_instance_warmup = 300
}
```

**Rationale**:
- CPU target of 50% provides headroom for bursts (t3 instances)
- Target tracking automatically manages scale up/down
- 300-second warmup prevents scaling thrashing
- Simpler than step scaling for web workloads

**Alternative Considered**: ALB request count per target
**Retained as Secondary**: Can add as additional policy for traffic-based scaling

### 6.3 Health Check Configuration

**Decision**: Use ELB health checks

```hcl
health_check_type         = "ELB"
health_check_grace_period = 300
```

**Rationale**:
- ELB health checks validate application readiness (not just instance status)
- 300-second grace period allows nginx installation and startup
- Prevents premature instance termination during launch

---

## 7. Monitoring and Observability

### 7.1 Monitoring Strategy

**Decision**: CloudWatch metrics with basic alarms

**Required Metrics**:
- **ALB**: TargetResponseTime, HTTPCode_Target_5XX_Count, UnHealthyHostCount
- **ASG**: GroupDesiredCapacity, GroupInServiceInstances
- **EC2**: CPUUtilization, NetworkIn, NetworkOut

**Rationale**:
- Built-in CloudWatch integration
- No additional cost for basic metrics
- Sufficient for initial deployment monitoring

### 7.2 Logging

**Decision**: Enable ALB access logs to S3

**Configuration**:
```hcl
access_logs {
  enabled = true
  bucket  = var.log_bucket_name
  prefix  = "alb-logs"
}
```

**Rationale**:
- Audit trail for security and compliance
- Troubleshooting traffic patterns
- Cost-effective (S3 storage only)

**Optional Enhancement**: VPC Flow Logs for network traffic analysis

---

## 8. Cost Optimization

### 8.1 Instance Sizing

**Decision**: Start small, scale based on metrics

**Strategy**:
- Development: t3.micro (2 instances) = ~$12/month
- Production: t3.small (2-4 instances) = ~$24-48/month
- High traffic: t3.medium or c7i.large as needed

**Rationale**:
- T3 burstable instances cost-effective for variable workloads
- Auto Scaling prevents over-provisioning
- Can upgrade instance type without architecture changes

### 8.2 NAT Gateway Optimization

**Decision**: Single NAT Gateway for cost optimization

**Consideration**:
- Production: NAT Gateway per AZ for high availability
- Development/Testing: Single NAT Gateway sufficient
- Cost: $32/month per NAT Gateway + data transfer

**Rationale**:
- Balance cost and availability requirements
- Can upgrade to multi-NAT Gateway for production

---

## 9. Deployment Strategy

### 9.1 Nginx Installation

**Decision**: User data script for automated nginx installation

**Script**:
```bash
#!/bin/bash
yum update -y
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# Create health check endpoint
cat > /usr/share/nginx/html/health <<EOF
healthy
EOF

# Start nginx
systemctl restart nginx
```

**Rationale**:
- Automated deployment, no manual configuration
- Idempotent installation process
- Health endpoint created automatically

### 9.2 Terraform State Management

**Decision**: HCP Terraform remote state with cloud backend

**Configuration**:
```hcl
terraform {
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name = "sandbox_<repo-name>"
      project = "sandbox"
    }
  }
}
```

**Rationale**:
- Constitution requirement for HCP Terraform integration
- Remote state for team collaboration
- State locking prevents concurrent modifications
- Workspace-based environment separation

---

## 10. Alternatives Considered and Rejected

### 10.1 ECS/Fargate for Container Deployment

**Rejected Because**:
- Specification explicitly requires EC2 instances
- Additional complexity not justified for simple nginx deployment
- Higher learning curve for operations team
- EC2 provides direct control over instance configuration

### 10.2 Public EC2 Instances (No ALB)

**Rejected Because**:
- Violates security best practices
- No load balancing or health checks
- Single point of failure
- Direct internet exposure increases attack surface

### 10.3 Network Load Balancer (NLB)

**Rejected Because**:
- Layer 4 load balancing insufficient for HTTP workloads
- ALB provides better HTTP routing and health checks
- Specification requires Application Load Balancer
- ALB preferred for web applications

### 10.4 Fixed-Size EC2 Instances (No Auto Scaling)

**Rejected Because**:
- Cannot handle traffic spikes
- No automatic failover for instance failures
- Manual capacity management required
- Violates FR-011 (Auto Scaling requirement)

### 10.5 Public Terraform Registry Modules

**Rejected Because**:
- Violates constitution Module-First Architecture (Section 1.1)
- Private registry modules are approved and maintained
- Organization requires private registry consumption
- Compliance and security standards enforced via private modules

---

## 11. Implementation Readiness

### 11.1 Prerequisites Confirmed

✅ All required modules available in private registry
✅ AWS provider version confirmed (6.19.0)
✅ Regional availability validated (ap-southeast-2)
✅ Security architecture defined
✅ Instance types selected
✅ Auto Scaling strategy determined

### 11.2 No Blockers Identified

- All NEEDS CLARIFICATION items resolved
- Module capabilities match requirements
- Security requirements achievable with selected modules
- Cost estimates within reasonable ranges

### 11.3 Ready for Implementation Planning

This research phase confirms:
1. Technical feasibility using private registry modules
2. Security compliance with organizational standards
3. Cost-effective architecture for nginx web serving
4. High availability with multi-AZ deployment
5. Scalability via Auto Scaling and ALB

**Next Phase**: Proceed to `/speckit.tasks` for detailed implementation task breakdown

---

## 12. References

- **Private Registry**: app.terraform.io/hashi-demos-apj
- **AWS Provider Documentation**: registry.terraform.io/providers/hashicorp/aws/latest
- **Security Analysis**: /workspace/ec2-alb-nginx-security-analysis.md
- **Module Sources**:
  - VPC: github.com/hashi-demo-lab/terraform-aws-vpc
  - EC2: github.com/hashi-demo-lab/terraform-aws-ec2-instance
  - ALB: github.com/hashi-demo-lab/terraform-aws-alb
  - ASG: github.com/hashi-demo-lab/terraform-aws-autoscaling

---

**Research Completed**: 2025-11-06
**Status**: All requirements validated and resolved
**Recommendation**: Proceed to implementation planning
