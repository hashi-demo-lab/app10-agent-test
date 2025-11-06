# Quickstart: EC2 Nginx Web Server with ALB

**Feature**: 001-ec2-nginx-alb
**Deployment Time**: ~10 minutes
**Prerequisites**: HCP Terraform account, AWS credentials, GitHub repository access

---

## Overview

Deploy a highly available nginx web server infrastructure in AWS ap-southeast-2 using private registry Terraform modules in under 10 minutes.

**What You'll Deploy**:
- VPC with public/private subnets across 2 AZs
- Application Load Balancer (internet-facing)
- Auto Scaling Group (2-4 EC2 instances)
- nginx web servers with automatic configuration

---

## Prerequisites Checklist

- [ ] HCP Terraform account with organization: `hashi-demos-apj`
- [ ] Project: `sandbox`
- [ ] AWS credentials configured (workspace variable set)
- [ ] GitHub repository access
- [ ] Terraform CLI installed (>= 1.8)
- [ ] `TFE_TOKEN` environment variable set

---

## Quick Start (5 Steps)

### Step 1: Clone and Branch

```bash
# Navigate to your repository
cd <your-repo>

# Create feature branch
git checkout -b 001-ec2-nginx-alb
```

### Step 2: Generate Terraform Code

The infrastructure code will be generated during the `/speckit.implement` phase. For now, we're in the planning phase.

**Expected Files** (after implementation):
- `main.tf` - Module declarations
- `variables.tf` - Input variables
- `outputs.tf` - Infrastructure outputs
- `providers.tf` - AWS provider config
- `versions.tf` - Version constraints
- `override.tf` - HCP Terraform backend
- `sandbox.auto.tfvars.example` - Example variables

### Step 3: Configure Variables

Create `sandbox.auto.tfvars` with your values:

```hcl
# Network Configuration
region             = "ap-southeast-2"
availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
vpc_cidr           = "10.0.0.0/16"
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]

# Compute Configuration
instance_type = "t3.micro"  # or "t3.small" for production
min_size      = 2
max_size      = 4

# Tagging
environment = "sandbox"
project     = "nginx-web-server"
```

### Step 4: Initialize and Validate

```bash
# Configure HCP Terraform credentials
mkdir -p ~/.terraform.d
cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Review plan
terraform plan
```

### Step 5: Deploy Infrastructure

```bash
# Apply configuration (will trigger HCP Terraform run)
terraform apply

# Get ALB DNS endpoint
terraform output alb_dns_name

# Test deployment
curl http://$(terraform output -raw alb_dns_name)
# Should return nginx welcome page
```

---

## Access Your Infrastructure

### Primary Endpoint

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP access
curl http://$ALB_DNS

# Expected response:
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# ...
```

### Health Check Endpoint

```bash
curl http://$ALB_DNS/health
# Expected: "healthy"
```

### Verify Auto Scaling

```bash
# Get Auto Scaling Group name
ASG_NAME=$(terraform output -raw autoscaling_group_name)

# Check instance count
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region ap-southeast-2 \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table
```

---

## Common Tasks

### Scale Instances

**Manually adjust capacity**:
```bash
# Edit variables
vim sandbox.auto.tfvars
# Update min_size, max_size, or desired_capacity

# Apply changes
terraform apply
```

**Auto Scaling will handle**:
- CPU-based scaling (target: 50%)
- Instance health monitoring
- Multi-AZ distribution

### Access EC2 Instances

**Using Systems Manager Session Manager** (no SSH keys required):

```bash
# List instances
aws ec2 describe-instances \
  --region ap-southeast-2 \
  --filters "Name=tag:Environment,Values=sandbox" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,State.Name]' \
  --output table

# Start session
aws ssm start-session \
  --target <instance-id> \
  --region ap-southeast-2

# Check nginx status
sudo systemctl status nginx
```

### View Logs

**ALB Access Logs**:
```bash
# Check CloudWatch Logs
aws logs tail /aws/elasticloadbalancing/app/<alb-name> \
  --region ap-southeast-2 \
  --follow
```

**Instance Logs**:
```bash
# Connect via Session Manager
aws ssm start-session --target <instance-id>

# View nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## Troubleshooting

### ALB Health Checks Failing

**Symptoms**: Instances marked as "unhealthy" in target group

**Debug Steps**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-southeast-2

# Common causes:
# 1. nginx not running on instance
# 2. Security group blocking ALB → EC2 traffic
# 3. Health check endpoint /health not responding

# Fix: Connect to instance and check nginx
aws ssm start-session --target <instance-id>
sudo systemctl status nginx
curl localhost/health
```

### No Instances Launching

**Symptoms**: Auto Scaling Group stuck at 0 instances

**Debug Steps**:
```bash
# Check ASG activity
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --region ap-southeast-2 \
  --max-records 10

# Common causes:
# 1. Invalid AMI ID
# 2. Insufficient EC2 capacity in AZ
# 3. IAM permissions missing
# 4. Subnet misconfiguration

# Fix: Review ASG activity errors
```

### Cannot Access ALB DNS

**Symptoms**: Connection timeout or refused

**Debug Steps**:
```bash
# Verify ALB is active
aws elbv2 describe-load-balancers \
  --region ap-southeast-2 \
  --query 'LoadBalancers[?LoadBalancerName==`<name>`].[State.Code,DNSName]'

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <alb-security-group-id> \
  --region ap-southeast-2

# Common causes:
# 1. Security group not allowing port 80 from 0.0.0.0/0
# 2. ALB listener not configured
# 3. No healthy targets

# Fix: Review security group ingress rules
```

### High Costs

**Symptoms**: Unexpected AWS charges

**Check**:
```bash
# Review running resources
terraform show

# Common cost drivers:
# 1. NAT Gateway ($43/month per gateway)
# 2. ALB ($24-35/month)
# 3. EC2 instances (2x t3.micro = $20/month)
# 4. Data transfer charges

# Cost optimization:
# - Use single NAT Gateway for dev/test
# - Scale down instance types (t3.micro)
# - Enable auto-destroy for ephemeral workspaces
```

---

## Testing Checklist

- [ ] ALB DNS endpoint responds to HTTP requests
- [ ] nginx welcome page displays correctly
- [ ] Health check endpoint `/health` returns "healthy"
- [ ] At least 2 EC2 instances running across 2 AZs
- [ ] Target group shows healthy instances
- [ ] Auto Scaling Group maintains desired capacity
- [ ] Security groups configured correctly (ALB → EC2 only)
- [ ] Systems Manager Session Manager access works
- [ ] CloudWatch metrics collecting data

---

## Cleanup

### Destroy Ephemeral Resources

```bash
# Destroy all infrastructure
terraform destroy

# Confirm destruction
# Type: yes

# Verify cleanup
terraform show
# Should show: No resources.
```

### Delete Workspace (Optional)

```bash
# For ephemeral workspaces only
# HCP Terraform UI → Workspaces → <workspace-name> → Settings → Destruction and Deletion → Queue destroy plan

# Or use CLI
terraform workspace select default
terraform workspace delete sandbox_<repo-name>
```

---

## Next Steps

### Production Readiness

1. **Enable HTTPS**:
   - Request ACM certificate
   - Add HTTPS listener to ALB
   - Redirect HTTP to HTTPS

2. **Enhance Monitoring**:
   - Create CloudWatch dashboards
   - Configure alarms for critical metrics
   - Enable VPC Flow Logs

3. **Improve Availability**:
   - Add NAT Gateway per AZ
   - Increase max_size for Auto Scaling
   - Configure cross-region backup

4. **Security Hardening**:
   - Enable WAF on ALB
   - Configure AWS Config rules
   - Implement GuardDuty monitoring

5. **Cost Optimization**:
   - Upgrade to Savings Plans
   - Use Graviton instances (t4g)
   - Implement auto-stop for dev environments

---

## Architecture Reference

```
Internet → ALB (public) → Target Group → EC2 Instances (private) → nginx
                                          ↓
                                    NAT Gateway → Internet
```

**Security Layers**:
1. Network: Private subnets, security group chaining
2. Identity: IAM instance profiles, Session Manager
3. Data: EBS encryption, TLS for package downloads

---

## Support Resources

**Documentation**:
- [Specification](./spec.md) - Requirements and success criteria
- [Plan](./plan.md) - Architecture and design decisions
- [Data Model](./data-model.md) - Infrastructure components
- [Research](./research.md) - Module selection and best practices

**HCP Terraform**:
- Organization: hashi-demos-apj
- Project: sandbox
- Workspace: sandbox_<repo-name>

**AWS Resources**:
- Region: ap-southeast-2 (Sydney)
- Availability Zones: ap-southeast-2a, ap-southeast-2b

**Module Registry**:
- VPC: app.terraform.io/hashi-demos-apj/vpc/aws
- ALB: app.terraform.io/hashi-demos-apj/alb/aws
- Auto Scaling: app.terraform.io/hashi-demos-apj/autoscaling/aws

---

**Quickstart Version**: 1.0
**Last Updated**: 2025-11-06
**Estimated Deployment Time**: 8-10 minutes
**Estimated Cost**: $95-100/month (sandbox environment)
