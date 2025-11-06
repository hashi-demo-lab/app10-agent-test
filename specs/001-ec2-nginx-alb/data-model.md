# Infrastructure Data Model: EC2 Nginx Web Server with ALB

**Feature**: 001-ec2-nginx-alb
**Date**: 2025-11-06

## Overview

This document defines the infrastructure components, their attributes, relationships, and state transitions for the EC2 nginx web server with Application Load Balancer deployment.

---

## Component Definitions

### 1. VPC (Virtual Private Cloud)

**Purpose**: Network isolation and connectivity foundation

**Attributes**:
- `vpc_id`: Unique identifier for the VPC
- `cidr_block`: IPv4 address range (e.g., 10.0.0.0/16)
- `region`: AWS region (ap-southeast-2)
- `enable_dns_hostnames`: Boolean (true)
- `enable_dns_support`: Boolean (true)
- `tags`: Resource metadata

**State**:
- `available`: VPC is created and ready
- `pending`: VPC is being created

**Dependencies**: None (foundational resource)

**Managed By**: `hashi-demos-apj/vpc/aws` module

**Lifecycle**:
```
Create → Available → (Modify) → Available → Destroy
```

---

### 2. Subnets

**Purpose**: Network segmentation across availability zones

#### 2.1 Public Subnets

**Attributes**:
- `subnet_id`: Unique identifier
- `cidr_block`: IPv4 range (e.g., 10.0.1.0/24, 10.0.2.0/24)
- `availability_zone`: ap-southeast-2a, ap-southeast-2b
- `map_public_ip_on_launch`: Boolean (true)
- `vpc_id`: Parent VPC reference
- `tags`: Resource metadata

**Placement**:
- Application Load Balancer
- NAT Gateway
- Internet Gateway attachment

**Count**: 2 (one per availability zone)

#### 2.2 Private Subnets

**Attributes**:
- `subnet_id`: Unique identifier
- `cidr_block`: IPv4 range (e.g., 10.0.11.0/24, 10.0.12.0/24)
- `availability_zone`: ap-southeast-2a, ap-southeast-2b
- `map_public_ip_on_launch`: Boolean (false)
- `vpc_id`: Parent VPC reference
- `tags`: Resource metadata

**Placement**:
- EC2 instances (nginx servers)

**Count**: 2 (one per availability zone)

**Managed By**: `hashi-demos-apj/vpc/aws` module

---

### 3. Internet Gateway

**Purpose**: Enable internet connectivity for public subnets

**Attributes**:
- `igw_id`: Unique identifier
- `vpc_id`: Parent VPC reference
- `tags`: Resource metadata

**State**:
- `attached`: Connected to VPC and functional
- `available`: Created but not attached
- `detached`: Disconnected from VPC

**Dependencies**: VPC

**Managed By**: `hashi-demos-apj/vpc/aws` module

---

### 4. NAT Gateway

**Purpose**: Provide outbound internet access for private subnet resources

**Attributes**:
- `nat_gateway_id`: Unique identifier
- `allocation_id`: Elastic IP allocation
- `subnet_id`: Public subnet placement
- `connectivity_type`: "public"
- `tags`: Resource metadata

**State**:
- `pending`: Being created
- `available`: Ready for traffic
- `deleting`: Being destroyed
- `deleted`: Removed

**Dependencies**:
- Internet Gateway
- Public Subnet
- Elastic IP

**Count**: 1 (cost optimization) or 2 (high availability)

**Managed By**: `hashi-demos-apj/vpc/aws` module

---

### 5. Route Tables

#### 5.1 Public Route Table

**Routes**:
- `0.0.0.0/0` → Internet Gateway
- `10.0.0.0/16` → local (VPC)

**Subnet Associations**: Public subnets

#### 5.2 Private Route Table

**Routes**:
- `0.0.0.0/0` → NAT Gateway
- `10.0.0.0/16` → local (VPC)

**Subnet Associations**: Private subnets

**Managed By**: `hashi-demos-apj/vpc/aws` module

---

### 6. Application Load Balancer (ALB)

**Purpose**: Distribute HTTP traffic across EC2 instances

**Attributes**:
- `arn`: Amazon Resource Name
- `dns_name`: Public DNS endpoint (primary access point)
- `zone_id`: Route53 hosted zone ID
- `load_balancer_type`: "application"
- `scheme`: "internet-facing"
- `ip_address_type`: "ipv4"
- `subnets`: Public subnet list (multi-AZ)
- `security_groups`: List of security group IDs
- `enable_deletion_protection`: Boolean (false for ephemeral)
- `tags`: Resource metadata

**State**:
- `provisioning`: Being created
- `active`: Accepting and routing traffic
- `active_impaired`: Functional with degraded performance
- `failed`: Creation failed

**Dependencies**:
- VPC
- Public Subnets (minimum 2 AZs)
- Security Group

**Outputs**:
- Primary endpoint: `<alb-name>-<random>.ap-southeast-2.elb.amazonaws.com`

**Managed By**: `hashi-demos-apj/alb/aws` module

---

### 7. Target Group

**Purpose**: Group EC2 instances for ALB traffic routing

**Attributes**:
- `arn`: Amazon Resource Name
- `name`: Target group identifier
- `port`: 80 (HTTP)
- `protocol`: "HTTP"
- `vpc_id`: Parent VPC reference
- `target_type`: "instance"
- `deregistration_delay`: 30 seconds
- `health_check`: Health check configuration object
- `tags`: Resource metadata

**Health Check Configuration**:
```hcl
{
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

**State**:
- Targets can be: `initial`, `healthy`, `unhealthy`, `unused`, `draining`, `unavailable`

**Dependencies**:
- VPC
- ALB

**Managed By**: `hashi-demos-apj/alb/aws` module

---

### 8. ALB Listener

**Purpose**: Accept incoming HTTP requests on port 80

**Attributes**:
- `arn`: Amazon Resource Name
- `load_balancer_arn`: Parent ALB reference
- `port`: 80
- `protocol`: "HTTP"
- `default_action`: Forward to target group
- `tags`: Resource metadata

**Default Action**:
```hcl
{
  type             = "forward"
  target_group_arn = <target_group_arn>
}
```

**Dependencies**:
- ALB
- Target Group

**Managed By**: `hashi-demos-apj/alb/aws` module

---

### 9. Security Groups

#### 9.1 ALB Security Group

**Purpose**: Control inbound traffic to load balancer

**Ingress Rules**:
```hcl
{
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTP from internet"
}
```

**Egress Rules**:
```hcl
{
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_groups = [ec2_security_group_id]
  description     = "Allow HTTP to EC2 instances"
}
```

#### 9.2 EC2 Security Group

**Purpose**: Control inbound traffic to EC2 instances

**Ingress Rules**:
```hcl
{
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_groups = [alb_security_group_id]
  description     = "Allow HTTP from ALB only"
}
```

**Egress Rules**:
```hcl
# HTTPS for package downloads
{
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTPS outbound for package updates"
}

# HTTP for package repositories
{
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTP outbound for package repositories"
}
```

**Dependencies**: VPC

**Managed By**: Module-managed security groups

---

### 10. EC2 Launch Template

**Purpose**: Define EC2 instance configuration for Auto Scaling

**Attributes**:
- `id`: Unique identifier
- `name`: Template name
- `image_id`: Amazon Linux 2023 AMI ID
- `instance_type`: t3.micro or t3.small
- `key_name`: SSH key pair (optional)
- `user_data`: Base64-encoded bootstrap script
- `iam_instance_profile`: Instance profile ARN
- `vpc_security_group_ids`: List of security group IDs
- `metadata_options`: IMDSv2 configuration
- `block_device_mappings`: EBS volume configuration
- `tags`: Resource metadata

**User Data Script**:
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

systemctl restart nginx
```

**IMDSv2 Configuration**:
```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"  # IMDSv2 enforcement
  http_put_response_hop_limit = 1
}
```

**EBS Configuration**:
```hcl
block_device_mappings {
  device_name = "/dev/xvda"
  ebs {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true  # Default encryption
    delete_on_termination = true
  }
}
```

**Dependencies**:
- AMI (data source)
- IAM Instance Profile
- Security Group

**Managed By**: `hashi-demos-apj/autoscaling/aws` module

---

### 11. IAM Instance Profile

**Purpose**: Provide EC2 instances with AWS API access credentials

**Attributes**:
- `arn`: Amazon Resource Name
- `name`: Instance profile name
- `role`: IAM role ARN

**Attached Policies**:
- `AmazonSSMManagedInstanceCore` (AWS managed)
  - Enables Systems Manager Session Manager
  - CloudWatch Logs integration
  - No SSH keys required

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

**Dependencies**: IAM Role

**Managed By**: `hashi-demos-apj/autoscaling/aws` module

---

### 12. Auto Scaling Group

**Purpose**: Manage EC2 instance fleet with automatic scaling

**Attributes**:
- `id`: Auto Scaling Group ID
- `arn`: Amazon Resource Name
- `name`: ASG identifier
- `min_size`: 2 (high availability minimum)
- `max_size`: 4 (capacity limit)
- `desired_capacity`: 2 (initial capacity)
- `vpc_zone_identifier`: Private subnet IDs (multi-AZ)
- `health_check_type`: "ELB"
- `health_check_grace_period`: 300 seconds
- `default_cooldown`: 300 seconds
- `target_group_arns`: ALB target group list
- `launch_template`: Launch template reference
- `tags`: Resource metadata

**State Transitions**:
```
Initial → Launching instances → InService → (Scaling) → InService → Terminating
```

**Scaling Events**:
- `Scale Up`: desired_capacity increases
- `Scale Down`: desired_capacity decreases
- `Replace Unhealthy`: Terminate and replace failed instances

**Dependencies**:
- Launch Template
- VPC Subnets (private)
- Target Group

**Managed By**: `hashi-demos-apj/autoscaling/aws` module

---

### 13. Scaling Policy

**Purpose**: Automatically adjust Auto Scaling Group capacity

**Type**: Target Tracking

**Attributes**:
- `name`: Policy identifier
- `policy_type`: "TargetTrackingScaling"
- `autoscaling_group_name`: Parent ASG reference
- `target_value`: 50.0 (CPU percentage)
- `predefined_metric_type`: "ASGAverageCPUUtilization"
- `estimated_instance_warmup`: 300 seconds

**Behavior**:
- **Scale Up Trigger**: Average CPU > 50%
- **Scale Down Trigger**: Average CPU < 50%
- **Cooldown**: Prevents rapid scaling oscillations
- **Warmup**: Excludes new instances from metrics during startup

**State Transitions**:
```
Idle → Alarm (metric breach) → Scaling Activity → Cooldown → Idle
```

**Dependencies**: Auto Scaling Group

**Managed By**: `hashi-demos-apj/autoscaling/aws` module

---

### 14. EC2 Instances

**Purpose**: Run nginx web server processes

**Attributes**:
- `instance_id`: Unique identifier
- `private_ip_address`: VPC private IP
- `availability_zone`: ap-southeast-2a or ap-southeast-2b
- `instance_type`: t3.micro or t3.small
- `ami_id`: Amazon Linux 2023 AMI
- `subnet_id`: Private subnet placement
- `security_groups`: EC2 security group
- `iam_instance_profile`: Instance profile ARN
- `state`: Instance lifecycle state
- `tags`: Resource metadata

**State Lifecycle**:
```
pending → running → (stopping) → stopped → (terminating) → terminated
```

**Health States**:
- **EC2 Health**: `passed` or `impaired`
- **ELB Health**: `healthy`, `unhealthy`, `initial`, `draining`

**Dependencies**:
- Launch Template
- Private Subnet
- Security Group
- IAM Instance Profile

**Managed By**: Auto Scaling Group (dynamic fleet management)

---

## Component Relationships

### Hierarchical Structure

```
VPC
├── Internet Gateway
├── NAT Gateway (in public subnet)
├── Public Subnets (2 AZs)
│   └── Application Load Balancer
│       ├── Listener (HTTP:80)
│       └── Target Group
│           └── Health Checks
└── Private Subnets (2 AZs)
    └── Auto Scaling Group
        ├── Launch Template
        │   ├── AMI (data source)
        │   ├── User Data (nginx install)
        │   └── IAM Instance Profile
        ├── Scaling Policy (CPU target tracking)
        └── EC2 Instances (2-4)
            └── nginx processes
```

### Data Flow

**Incoming Traffic**:
```
Internet → ALB (public subnet) → Target Group → EC2 Instances (private subnet) → nginx
```

**Outbound Traffic**:
```
EC2 Instances (private subnet) → NAT Gateway (public subnet) → Internet Gateway → Internet
```

**Health Check Flow**:
```
ALB → Target Group Health Check → EC2:80/health → nginx response → ALB (mark healthy/unhealthy)
```

**Scaling Flow**:
```
CloudWatch Metrics → Scaling Policy → Auto Scaling Group → Launch/Terminate Instances
```

---

## State Management

### Terraform State Structure

**Primary Resources**:
```
module.vpc
  ├── aws_vpc.this
  ├── aws_subnet.public[0-1]
  ├── aws_subnet.private[0-1]
  ├── aws_internet_gateway.this
  ├── aws_nat_gateway.this
  └── aws_route_table.public/private

module.alb
  ├── aws_lb.this
  ├── aws_lb_target_group.this
  ├── aws_lb_listener.http
  └── aws_security_group.alb

module.autoscaling
  ├── aws_launch_template.this
  ├── aws_autoscaling_group.this
  ├── aws_autoscaling_policy.cpu_tracking
  ├── aws_iam_role.this
  ├── aws_iam_instance_profile.this
  └── aws_security_group.ec2

data.aws_ami.amazon_linux_2023
data.aws_availability_zones.available
```

### State Dependencies

**Creation Order**:
1. VPC → Subnets → Internet Gateway
2. NAT Gateway → Route Tables
3. Security Groups
4. ALB → Target Group → Listener
5. IAM Role → Instance Profile
6. Launch Template → Auto Scaling Group → Scaling Policy
7. ASG attachment to Target Group

**Destruction Order**: Reverse of creation

---

## Configuration Variables

### Required Inputs

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `region` | string | AWS region | "ap-southeast-2" |
| `availability_zones` | list(string) | AZs for deployment | ["ap-southeast-2a", "ap-southeast-2b"] |
| `vpc_cidr` | string | VPC CIDR block | "10.0.0.0/16" |
| `public_subnets` | list(string) | Public subnet CIDRs | ["10.0.1.0/24", "10.0.2.0/24"] |
| `private_subnets` | list(string) | Private subnet CIDRs | ["10.0.11.0/24", "10.0.12.0/24"] |
| `instance_type` | string | EC2 instance type | "t3.micro" |
| `min_size` | number | ASG minimum instances | 2 |
| `max_size` | number | ASG maximum instances | 4 |
| `environment` | string | Environment name | "sandbox" |

### Computed Outputs

| Output | Type | Description | Usage |
|--------|------|-------------|-------|
| `alb_dns_name` | string | ALB public DNS | Primary access endpoint |
| `vpc_id` | string | VPC identifier | Reference for additional resources |
| `private_subnet_ids` | list(string) | Private subnet IDs | Instance placement verification |
| `alb_arn` | string | ALB ARN | Monitoring and logging |
| `target_group_arn` | string | Target group ARN | Health check monitoring |
| `autoscaling_group_name` | string | ASG name | CloudWatch metrics |

---

## Validation Rules

### Infrastructure Constraints

1. **Multi-AZ Requirement**: Minimum 2 availability zones
2. **Subnet CIDR**: Must be within VPC CIDR range
3. **Instance Count**: min_size ≤ desired_capacity ≤ max_size
4. **Security Groups**: No 0.0.0.0/0 ingress to EC2 instances
5. **Health Check**: Must return HTTP 200 from /health endpoint
6. **IMDSv2**: Must be enforced on all EC2 instances
7. **EBS Encryption**: Must be enabled by default

### Operational Requirements

1. **Health Check Grace Period**: ≥ nginx startup time (300 seconds)
2. **Deregistration Delay**: ≥ max request duration (30 seconds)
3. **Scaling Cooldown**: ≥ instance warmup time (300 seconds)
4. **Target Tracking**: CPU target 40-70% for t3 instances

---

## Component Lifecycle Examples

### EC2 Instance Lifecycle

```
1. ASG determines scale-up needed
2. Launch Template provisions new instance
3. Instance enters "pending" state
4. User data executes (nginx installation)
5. Instance enters "running" state
6. Health check grace period (300s)
7. ALB health checks begin
8. 2 consecutive successful health checks
9. Instance marked "healthy" in target group
10. ALB begins routing traffic to instance
```

### Instance Replacement on Failure

```
1. ALB health check fails (3 consecutive failures)
2. Instance marked "unhealthy" in target group
3. ALB stops sending traffic to instance
4. ASG detects unhealthy instance (ELB health check)
5. ASG initiates instance termination
6. Instance enters "draining" state (30s)
7. In-flight requests complete
8. Instance terminated
9. ASG launches replacement instance
10. New instance follows standard lifecycle
```

### Scaling Event

```
1. CloudWatch: Average CPU > 50% for 3 minutes
2. Scaling Policy: Calculate required capacity
3. ASG: Increase desired_capacity
4. ASG: Launch new instances (up to max_size)
5. Instances: Follow standard lifecycle
6. CloudWatch: CPU drops below 50%
7. Scaling Policy: Calculate required capacity
8. ASG: Decrease desired_capacity
9. ASG: Select instances for termination (oldest first)
10. ASG: Terminate excess instances
```

---

## Security Model

### Least Privilege Access

**Network Layer**:
- EC2 instances: No public IPs, private subnet only
- ALB: Public subnets, internet-facing
- Security groups: Chained (ALB → EC2), no 0.0.0.0/0 to instances

**Identity Layer**:
- EC2: IAM instance profile (no static credentials)
- Systems Manager: Session Manager for access (no SSH keys)
- IMDSv2: Required (prevents credential theft)

**Data Layer**:
- EBS: Encryption enabled by default
- TLS: Outbound package downloads
- Logs: CloudWatch Logs (encrypted)

---

**Data Model Status**: Complete
**Last Updated**: 2025-11-06
**Ready for**: Implementation phase
