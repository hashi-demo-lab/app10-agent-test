# Implementation Plan: EC2 Nginx Web Server with Application Load Balancer

**Branch**: `001-ec2-nginx-alb` | **Date**: 2025-11-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ec2-nginx-alb/spec.md`

## Summary

Deploy a highly available nginx web server infrastructure in AWS ap-southeast-2 using EC2 instances behind an Application Load Balancer with Auto Scaling. The solution leverages private registry modules (hashi-demos-apj) for VPC, EC2, ALB, and Auto Scaling components. Architecture follows security best practices with EC2 instances in private subnets, ALB in public subnets, and multi-AZ deployment for 99.9% availability.

## Technical Context

**Infrastructure as Code**: Terraform ~> 1.8 with HCP Terraform cloud backend
**Cloud Provider**: AWS (provider version ~> 6.19)
**Region**: ap-southeast-2 (Sydney)
**Availability Zones**: ap-southeast-2a, ap-southeast-2b
**Compute**: EC2 instances (Amazon Linux 2023, t3.micro/t3.small)
**Web Server**: nginx (latest from Amazon Linux package repository)
**Load Balancer**: Application Load Balancer (ALB)
**Scaling**: Auto Scaling Group with target tracking policies
**Networking**: VPC with public/private subnets across 2 AZs
**Project Type**: Infrastructure deployment (Terraform modules)
**Performance Goals**: <100ms response time, 99.9% availability, auto-scale 2-4 instances
**Constraints**: HTTP-only (no HTTPS initially), private subnet placement for EC2, ap-southeast-2 region only
**Scale/Scope**: Support 2-4 EC2 instances, handle variable traffic with Auto Scaling, multi-AZ deployment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Section I: Foundational Principles

**1.1 Module-First Architecture** ✅ PASS
- All infrastructure uses approved private registry modules from app.terraform.io/hashi-demos-apj
- Modules: vpc/aws (6.5.0), ec2-instance/aws (6.1.4), alb/aws (10.1.0), autoscaling/aws (9.0.2)
- No direct resource declarations
- All module sources use `app.terraform.io/hashi-demos-apj/` prefix

**1.2 Specification-Driven Development** ✅ PASS
- Implementation driven by explicit spec.md requirements
- All 15 functional requirements mapped to module configurations
- No implicit assumptions - all decisions documented in research.md
- Code will reference FR-### requirements in comments

**1.3 Security-First Automation** ✅ PASS
- No static credentials generated
- IAM instance profiles for EC2 with Systems Manager access
- IMDSv2 enforcement via ec2-instance module
- Private subnet placement for EC2 instances
- Security group chaining (ALB → EC2 only)

### Section II: HCP Terraform Prerequisites

**2.1 Required Configuration Details** ✅ PASS
- Organization: hashi-demos-apj (provided by user)
- Project: sandbox (provided by user)
- Workspace: sandbox_<GITHUB_REPO_NAME> (will be determined from repo)
- Configuration validated before Terraform operations

### Section III: Code Generation Standards

**3.1 Repository Structure** ✅ PASS
- Single repository for infrastructure
- Feature branch: 001-ec2-nginx-alb
- Standard file structure: main.tf, variables.tf, outputs.tf, providers.tf, versions.tf

**3.2 File Organization** ✅ PASS
- Separate files for logical organization
- All files under 300 lines
- Module instantiations in main.tf
- No monolithic configurations

**3.3 Naming Conventions** ✅ PASS
- Resources: `<app>-<resource-type>-<purpose>` format
- Variables: snake_case with descriptive names
- Following HashiCorp naming standards
- No sensitive information in names

**3.4 Variable Management** ✅ PASS
- All variables will include description and type
- Sensitive variables marked appropriately
- Validation blocks for business logic constraints
- No default values for security-sensitive variables

**3.5 Module Usage Patterns** ✅ PASS
- Version constraints with `~>` for all modules
- Private registry sources (app.terraform.io/hashi-demos-apj)
- Module inputs mapped to variables (not hardcoded)
- Security rationale in comments

### Section IV: Security and Compliance

**3.1 Credential Management** ✅ PASS
- No static credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- Workspace variable sets for dynamic provider credentials
- IAM instance profiles for EC2 instances

**3.2 Security Best Practices** ✅ PASS
- Encryption enabled (EBS, data in transit)
- Public access restricted (EC2 in private subnets)
- Security patterns implemented proactively

**3.3 Secrets Management** ✅ PASS
- No secrets in Terraform code or state
- IAM roles for credential management
- Outputs marked sensitive where appropriate

**3.4 Least Privilege by Default** ✅ PASS
- EC2 in private subnets (no public IPs)
- Security groups: ALB from internet, EC2 from ALB only
- IAM: AmazonSSMManagedInstanceCore only
- IMDSv2 enforced
- EBS encryption enabled

### Section V: Workspace and Environment Management

**4.1 HCP Terraform Workspace Management** ✅ PASS
- Will not create permanent workspaces (pre-provisioned)
- Ephemeral workspace for testing: sandbox_<repo-name>
- Feature branch pushed before ephemeral workspace creation

**4.2 Variable Sets** ✅ PASS
- Will not duplicate variable set values
- Document expected variable sets in README
- Application-specific variables at workspace level

**4.3 Environment Promotion** ✅ PASS
- Feature branch from dev/main
- Human review required for all merges
- Environment-specific values externalized

### Section VI: Code Quality and Maintainability

**5.1 Documentation Requirements** ✅ PASS
- README.md with terraform-docs automation
- Inline comments for complex logic
- Module selections justified
- All variables/outputs have descriptions

**5.2 Code Style** ✅ PASS
- terraform fmt for formatting
- terraform validate for syntax
- Alphabetized arguments within blocks
- Consistent argument ordering

**5.3 Testing and Validation** ✅ PASS
- Pre-commit hooks configured
- terraform validate before commit
- Ephemeral workspace testing planned
- HCP Terraform UI plan review

**5.4 Version Control** ✅ PASS
- .gitignore excludes: .terraform/, *.tfstate, *.tfvars
- Atomic commits planned
- No secrets in version control

### Section VII: Operational Excellence

**6.1 State Management** ✅ PASS
- HCP Terraform cloud backend
- No local backend configuration
- State never committed to version control

**6.2 Dependency Management** ✅ PASS
- Provider versions with pessimistic constraints (~> 6.19)
- Module versions specified (~> X.Y)
- No `latest` or unconstrained versions

**6.3 Cost Optimization** ✅ PASS
- T3.micro for development, t3.small for production
- Auto Scaling prevents over-provisioning
- Idle resource cleanup considered

**6.4 Monitoring and Observability** ✅ PASS
- CloudWatch metrics enabled
- Tags include monitoring metadata
- Outputs for monitoring system integration

### Section X: Testing and Validation Framework

**10.1 Ephemeral Workspace Testing** ✅ PASS
- Plan includes ephemeral workspace creation
- Auto-apply and auto-destroy configured
- Variables at workspace level
- Feature branch committed before testing

**Gate Decision**: ✅ ALL GATES PASSED - Proceed to implementation

## Project Structure

### Documentation (this feature)

```text
specs/001-ec2-nginx-alb/
├── spec.md              # Feature specification (Phase 0)
├── plan.md              # This file (Phase 1)
├── research.md          # Module research and decisions (Phase 1)
├── data-model.md        # Infrastructure component model (Phase 1)
├── quickstart.md        # Deployment quickstart guide (Phase 1)
├── checklists/
│   └── requirements.md  # Specification quality checklist
└── tasks.md             # Implementation tasks (Phase 2, /speckit.tasks)
```

### Terraform Configuration (repository root)

```text
/
├── main.tf                        # Module declarations (VPC, ALB, ASG, EC2)
├── variables.tf                   # Input variable definitions
├── outputs.tf                     # Output values (ALB DNS, instance IDs)
├── providers.tf                   # AWS provider configuration
├── versions.tf                    # Terraform and provider version constraints
├── locals.tf                      # Local values and computed data
├── override.tf                    # HCP Terraform cloud backend for testing
├── sandbox.auto.tfvars.example    # Example variable values
├── sandbox.auto.tfvars            # Testing variable values (gitignored)
├── README.md                      # Project documentation (terraform-docs)
├── .gitignore                     # Terraform-specific gitignore
└── .pre-commit-config.yaml        # Pre-commit hooks configuration
```

### File Organization

**main.tf**: Module instantiations
- VPC module (public/private subnets, NAT Gateway, Internet Gateway)
- ALB module (load balancer, target groups, listeners)
- Auto Scaling Group module (launch template, scaling policies)
- Data sources (AMI lookup, availability zones)

**variables.tf**: All input variables
- Region and availability zone configuration
- VPC CIDR and subnet configuration
- Instance type and Auto Scaling capacity
- Tags and naming

**outputs.tf**: Infrastructure outputs
- ALB DNS endpoint (primary access point)
- VPC and subnet IDs
- Security group IDs
- Auto Scaling Group details

**Structure Decision**: Standard Terraform project structure for infrastructure deployment. All modules sourced from hashi-demos-apj private registry. Configuration files separate concerns for maintainability. Testing configuration (override.tf, sandbox.auto.tfvars) supports HCP Terraform cloud backend workflow.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**Status**: ✅ No constitution violations - complexity tracking not required

All gates passed. Implementation follows organizational standards without exceptions.

---

## Architecture Overview

### High-Level Design

```
┌────────────────────────────────────────────────────────────┐
│                     Internet (0.0.0.0/0)                   │
└──────────────────────┬─────────────────────────────────────┘
                       │ HTTP (Port 80)
                       ▼
┌────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)               │
│              Public Subnets (2 AZs)                        │
│              Security Group: Allow 80 from Internet        │
└──────────┬────────────────────────────┬────────────────────┘
           │                            │
           │ HTTP (Port 80)             │ HTTP (Port 80)
           │ (Security Group Chain)     │ (Security Group Chain)
           ▼                            ▼
┌──────────────────────────┐ ┌──────────────────────────────┐
│   ap-southeast-2a        │ │   ap-southeast-2b            │
│   Private Subnet         │ │   Private Subnet             │
│                          │ │                              │
│  ┌────────────────────┐  │ │  ┌────────────────────────┐  │
│  │ EC2 Instance       │  │ │  │ EC2 Instance           │  │
│  │ Amazon Linux 2023  │  │ │  │ Amazon Linux 2023      │  │
│  │ nginx              │  │ │  │ nginx                  │  │
│  │ t3.micro/t3.small  │  │ │  │ t3.micro/t3.small      │  │
│  └────────────────────┘  │ │  └────────────────────────┘  │
│                          │ │                              │
└────────┬─────────────────┘ └────────┬─────────────────────┘
         │                            │
         │ Outbound HTTPS/HTTP        │ Outbound HTTPS/HTTP
         │ (Package updates)          │ (Package updates)
         ▼                            ▼
┌────────────────────────────────────────────────────────────┐
│                   NAT Gateway (Public Subnet)              │
└──────────────────────┬─────────────────────────────────────┘
                       │
                       ▼
               Internet Gateway
                       │
                       ▼
                   Internet
```

### Component Breakdown

**1. VPC Module** (`hashi-demos-apj/vpc/aws`)
- Creates VPC with configurable CIDR (default: 10.0.0.0/16)
- Public subnets in 2 AZs for ALB and NAT Gateway
- Private subnets in 2 AZs for EC2 instances
- Internet Gateway for public subnet internet access
- NAT Gateway for private subnet outbound connectivity
- Route tables configured automatically

**2. ALB Module** (`hashi-demos-apj/alb/aws`)
- Application Load Balancer in public subnets
- Target group for EC2 instances
- HTTP listener on port 80
- Health checks to `/health` endpoint
- Security group allowing HTTP from internet
- DNS name output for access

**3. Auto Scaling Group Module** (`hashi-demos-apj/autoscaling/aws`)
- Launch template with nginx user data
- Auto Scaling Group (min: 2, max: 4)
- Target tracking scaling policy (CPU: 50%)
- Multi-AZ instance distribution
- ELB health check integration
- IAM instance profile for Systems Manager

**4. Data Sources**
- Latest Amazon Linux 2023 AMI
- Availability zones in ap-southeast-2

### Security Layers

**Layer 1: Network Isolation**
- EC2 instances in private subnets (no public IPs)
- ALB in public subnets (internet-facing)
- Security group chaining (ALB → EC2 only)

**Layer 2: Access Control**
- IAM instance profile for EC2 (no static credentials)
- Systems Manager Session Manager for instance access
- No SSH keys or bastion hosts required

**Layer 3: Data Protection**
- TLS for outbound package downloads
- EBS encryption enabled by default
- IMDSv2 enforcement on instances

**Layer 4: Monitoring**
- VPC Flow Logs (optional)
- ALB access logs to S3
- CloudWatch metrics and alarms

### Module Integration

```hcl
# VPC Module provides:
vpc_id → ALB module (security group)
vpc_id → ASG module (launch template)
public_subnet_ids → ALB module (placement)
private_subnet_ids → ASG module (instance placement)
nat_gateway_ips → Outputs (monitoring)

# ALB Module provides:
target_group_arn → ASG module (traffic source attachment)
security_group_id → ASG module (allows traffic from ALB)
dns_name → Outputs (primary endpoint)

# ASG Module provides:
autoscaling_group_name → Outputs (monitoring)
instance_ids → Outputs (troubleshooting)
launch_template_id → Outputs (configuration reference)

# Data Sources provide:
ami_id → ASG module (launch template)
availability_zones → VPC module (subnet placement)
```

### Implementation Phases

**Phase 1: Core Networking**
- Create VPC with public/private subnets
- Configure Internet Gateway and NAT Gateway
- Establish route tables and network ACLs
- Validate connectivity paths

**Phase 2: Load Balancer Setup**
- Deploy ALB in public subnets
- Create target group with health checks
- Configure HTTP listener on port 80
- Create ALB security group

**Phase 3: Compute Resources**
- Create Auto Scaling Group with launch template
- Configure user data for nginx installation
- Set up IAM instance profile
- Configure EC2 security group
- Attach target group to ASG

**Phase 4: Scaling Configuration**
- Implement target tracking scaling policy
- Configure health check grace period
- Set min/max/desired capacity
- Test scaling behavior

**Phase 5: Testing & Validation**
- Validate ALB health checks passing
- Test HTTP access via ALB DNS
- Verify auto scaling triggers
- Confirm multi-AZ distribution
- Validate security group rules

---

## Deployment Workflow

### Prerequisites
1. HCP Terraform organization: hashi-demos-apj
2. HCP Terraform project: sandbox
3. AWS credentials configured (workspace variable set)
4. GitHub repository access for VCS integration

### Initial Deployment

1. **Prepare Repository**
   ```bash
   git checkout -b 001-ec2-nginx-alb
   # Create Terraform configuration files
   git add .
   git commit -m "Add EC2 nginx ALB infrastructure"
   git push origin 001-ec2-nginx-alb
   ```

2. **Configure HCP Terraform Credentials**
   ```bash
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
   ```

3. **Initialize and Validate**
   ```bash
   terraform init
   terraform validate
   terraform fmt -check
   ```

4. **Create Ephemeral Workspace**
   - Workspace: `sandbox_<GITHUB_REPO_NAME>`
   - Project: sandbox
   - Auto-apply: enabled
   - Auto-destroy: 2 hours
   - VCS branch: 001-ec2-nginx-alb

5. **Configure Variables** (at workspace level)
   - `region`: ap-southeast-2
   - `availability_zones`: ["ap-southeast-2a", "ap-southeast-2b"]
   - `vpc_cidr`: 10.0.0.0/16
   - `public_subnets`: ["10.0.1.0/24", "10.0.2.0/24"]
   - `private_subnets`: ["10.0.11.0/24", "10.0.12.0/24"]
   - `instance_type`: t3.micro
   - `min_size`: 2
   - `max_size`: 4
   - `environment`: sandbox

6. **Execute Terraform Run**
   ```bash
   terraform plan
   # Review plan output in HCP Terraform UI
   # Auto-apply will trigger after successful plan
   ```

7. **Validate Deployment**
   ```bash
   # Get ALB DNS from outputs
   terraform output alb_dns_name

   # Test HTTP access
   curl http://<alb-dns-name>
   # Should return nginx welcome page
   ```

8. **Cleanup** (after validation)
   - Destroy ephemeral workspace resources
   - Delete workspace (auto-destroy after 2 hours)

### Production Promotion

1. **Review and Approve**
   - Review Terraform plan in HCP Terraform UI
   - Validate all resources in ephemeral workspace
   - Human approval required

2. **Promote to Dev**
   ```bash
   # Create pull request
   gh pr create \
     --base main \
     --head 001-ec2-nginx-alb \
     --title "Add EC2 nginx ALB infrastructure" \
     --body "Implements FR-001 through FR-015 per spec.md"
   ```

3. **Merge and Deploy**
   - Human review of PR
   - Merge to main branch
   - HCP Terraform VCS workflow triggers automatically
   - Monitor deployment in HCP Terraform UI

---

## Risk Assessment

### High Risks
- **ALB misconfiguration**: Mitigated by module defaults and health checks
- **Security group rules**: Mitigated by security group chaining and least privilege
- **NAT Gateway costs**: Mitigated by single NAT Gateway option for dev/test

### Medium Risks
- **Instance capacity**: Mitigated by Auto Scaling policies
- **Health check tuning**: Mitigated by research-based defaults
- **Cost overruns**: Mitigated by auto-destroy for ephemeral workspaces

### Low Risks
- **Regional service availability**: Validated in research phase
- **Module compatibility**: All modules from same organization
- **Version conflicts**: Pessimistic version constraints prevent breaking changes

---

## Cost Estimation

### Monthly Costs (ap-southeast-2)

**Compute** (2x t3.micro, 730 hours):
- 2 instances × $0.0138/hour × 730 hours = ~$20.15

**Load Balancer**:
- ALB: $24.48 (fixed) + $0.008/LCU-hour × usage = ~$30-35

**NAT Gateway** (single):
- $0.059/hour × 730 hours = ~$43.07
- Data processing: $0.059/GB × usage

**Data Transfer**:
- First 1 GB/month: Free
- Next 10 TB/month: $0.114/GB

**Total Estimated Cost**:
- **Minimum**: ~$95-100/month (single NAT, minimal traffic)
- **Production**: ~$150-200/month (dual NAT, moderate traffic)

### Cost Optimization Strategies
1. Use single NAT Gateway for dev/test environments
2. Start with t3.micro, upgrade only if needed
3. Enable auto-destroy for ephemeral workspaces
4. Monitor CloudWatch metrics to right-size instances
5. Use Auto Scaling to prevent over-provisioning

---

## Success Criteria Mapping

| Spec Requirement | Implementation | Validation Method |
|------------------|----------------|-------------------|
| FR-001: EC2 in ap-southeast-2 | VPC module with region variable | Terraform output validation |
| FR-002: nginx installed | User data script | HTTP request to ALB DNS |
| FR-003: HTTP port 80 | nginx configuration, ALB listener | curl http://alb-dns |
| FR-004: Create ALB | ALB module | AWS Console verification |
| FR-005: Distribute traffic | Target group + ASG attachment | Health check status |
| FR-006: 2 AZs | VPC module, ASG vpc_zone_identifier | Instance placement check |
| FR-007: Health checks | ALB target group health_check | CloudWatch metrics |
| FR-008: Remove unhealthy | ALB auto deregistration | Simulate instance failure |
| FR-009: ALB security group | Allow 80 from 0.0.0.0/0 | Security group rules review |
| FR-010: EC2 security group | Allow 80 from ALB SG only | Security group rules review |
| FR-011: Auto Scaling Group | ASG module with min/max | Terraform state |
| FR-012: Resource tags | Tags variable in all modules | AWS resource tags |
| FR-013: Terraform provisioning | All modules, HCP backend | Successful terraform apply |
| FR-014: Output ALB DNS | outputs.tf | terraform output command |
| FR-015: HTTP-only | No HTTPS listener | HTTP access works |

---

## Next Steps

1. ✅ Research complete (research.md)
2. ✅ Architecture designed (plan.md)
3. 🔄 **NEXT**: Create data-model.md for infrastructure components
4. 🔄 **NEXT**: Create quickstart.md for deployment guide
5. 🔄 **NEXT**: Run `/speckit.tasks` to generate implementation tasks
6. ⏳ **FUTURE**: Run `/speckit.implement` to generate Terraform code

---

**Plan Status**: Complete and ready for task generation
**Constitution Gates**: All passed ✅
**Ready for**: `/speckit.tasks` command
