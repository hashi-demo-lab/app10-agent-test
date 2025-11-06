# Security Best Practices: EC2 with nginx and Application Load Balancer

## Executive Summary

This document provides comprehensive security best practices for deploying EC2 instances running nginx behind an Application Load Balancer (ALB) in AWS. The recommendations are based on the AWS Well-Architected Framework Security Pillar, AWS Foundational Security Best Practices, and official AWS documentation.

**Key Security Principles:**
- Defense in Depth: Multiple layers of security controls
- Least Privilege: Minimal permissions and access rights
- Encryption Everywhere: Data protection in transit and at rest
- Monitoring and Logging: Comprehensive visibility and auditability
- Zero Trust Network: Assume breach and verify continuously

---

## 1. Security Group Configuration

### 1.1 Application Load Balancer Security Group

**Purpose:** Controls inbound traffic from the internet and outbound traffic to EC2 instances.

#### Recommended Rules - Internet-Facing ALB

**Inbound Rules:**

| Rule | Protocol | Port Range | Source | Purpose | Priority |
|------|----------|------------|--------|---------|----------|
| HTTP | TCP | 80 | 0.0.0.0/0, ::/0 | Public HTTP access (redirect to HTTPS) | Medium |
| HTTPS | TCP | 443 | 0.0.0.0/0, ::/0 | Public HTTPS access | Critical |

**Outbound Rules:**

| Rule | Protocol | Port Range | Destination | Purpose | Priority |
|------|----------|------------|-------------|---------|----------|
| HTTP | TCP | 80 | EC2-Security-Group-ID | Health checks and HTTP traffic to instances | Critical |
| HTTPS | TCP | 443 | EC2-Security-Group-ID | HTTPS traffic to instances (if using encrypted backend) | High |

**Security Considerations:**

1. **HTTP to HTTPS Redirect:** Configure HTTP listener (port 80) to redirect all traffic to HTTPS (port 443)
2. **IPv6 Support:** Include ::/0 for dual-stack deployments
3. **Minimize Exposure:** Only open ports 80 and 443; no SSH, RDP, or management ports
4. **Source IP Restrictions:** For internal ALBs, restrict source to VPC CIDR ranges only

#### Recommended Rules - Internal ALB

**Inbound Rules:**

| Rule | Protocol | Port Range | Source | Purpose |
|------|----------|------------|--------|---------|
| HTTPS | TCP | 443 | VPC-CIDR-Range | Internal HTTPS access only |

**Outbound Rules:**

| Rule | Protocol | Port Range | Destination | Purpose |
|------|----------|------------|-------------|---------|
| HTTP/HTTPS | TCP | 80/443 | EC2-Security-Group-ID | Traffic to backend instances |

---

### 1.2 EC2 Instance Security Group

**Purpose:** Controls inbound traffic from ALB and outbound traffic for updates and external services.

#### Recommended Rules

**Inbound Rules:**

| Rule | Protocol | Port Range | Source | Purpose | Priority |
|------|----------|------------|--------|---------|----------|
| HTTP | TCP | 80 | ALB-Security-Group-ID | Traffic from ALB only | Critical |
| HTTPS | TCP | 443 | ALB-Security-Group-ID | Encrypted traffic from ALB (optional) | High |
| ICMP | ICMP | All | ALB-Security-Group-ID | Path MTU Discovery | Medium |

**Outbound Rules:**

| Rule | Protocol | Port Range | Destination | Purpose | Priority |
|------|----------|------------|-------------|---------|----------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | OS updates, package downloads, AWS API calls | Critical |
| HTTP | TCP | 80 | 0.0.0.0/0 | Package repositories (prefer HTTPS) | Medium |
| DNS | UDP | 53 | VPC-DNS-Server | DNS resolution | Critical |
| NTP | UDP | 123 | 0.0.0.0/0 | Time synchronization | Medium |

**Critical Security Requirements:**

1. **No Direct Internet Access:** EC2 instances should NEVER accept traffic from 0.0.0.0/0 on any port
2. **Reference Security Groups:** Use security group IDs as sources instead of CIDR ranges for tighter coupling
3. **Stateful Filtering:** Security groups are stateful; return traffic is automatically allowed
4. **No SSH/RDP from Internet:** Use AWS Systems Manager Session Manager instead
5. **Deny by Default:** Only explicitly allowed traffic is permitted

**Anti-Patterns to Avoid:**

- Opening port 22 (SSH) or 3389 (RDP) to 0.0.0.0/0
- Using overly broad CIDR ranges (e.g., 10.0.0.0/8) when specific subnets suffice
- Allowing all traffic between security groups without justification
- Keeping unused rules that create unnecessary attack surface

---

### 1.3 Security Group Best Practices

1. **Naming Convention:** Use descriptive names (e.g., `prod-alb-external-sg`, `prod-nginx-instances-sg`)
2. **Description Requirements:** Document purpose of each rule with clear descriptions
3. **Regular Audits:** Review security group rules quarterly for unused or overly permissive entries
4. **Version Control:** Track security group changes via CloudFormation or Terraform
5. **Least Privilege:** Only open ports required for specific functionality
6. **Separation of Duties:** Use different security groups for different tiers (web, app, database)

**Compliance Requirements:**

- **CIS AWS Foundations Benchmark:** Security groups should not allow unrestricted access (0.0.0.0/0) to high-risk ports
- **PCI DSS:** Restrict access to cardholder data environment components
- **SOC 2:** Document and justify all security group rules as part of change management

---

## 2. VPC and Subnet Architecture

### 2.1 High Availability Multi-Tier Architecture

**Reference Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────┐    ┌───────────────────────┐       │
│  │  Public Subnet AZ-A   │    │  Public Subnet AZ-B   │       │
│  │  (10.0.1.0/24)        │    │  (10.0.2.0/24)        │       │
│  │  ┌─────────────────┐  │    │  ┌─────────────────┐  │       │
│  │  │  ALB Node AZ-A  │  │    │  │  ALB Node AZ-B  │  │       │
│  │  └─────────────────┘  │    │  └─────────────────┘  │       │
│  │  ┌─────────────────┐  │    │  ┌─────────────────┐  │       │
│  │  │  NAT Gateway    │  │    │  │  NAT Gateway    │  │       │
│  │  └─────────────────┘  │    │  └─────────────────┘  │       │
│  └───────────────────────┘    └───────────────────────┘       │
│              │                          │                      │
│  ┌───────────────────────┐    ┌───────────────────────┐       │
│  │  Private Subnet AZ-A  │    │  Private Subnet AZ-B  │       │
│  │  (10.0.11.0/24)       │    │  (10.0.12.0/24)       │       │
│  │  ┌─────────────────┐  │    │  ┌─────────────────┐  │       │
│  │  │  EC2 (nginx)    │  │    │  │  EC2 (nginx)    │  │       │
│  │  │  No Public IP   │  │    │  │  No Public IP   │  │       │
│  │  └─────────────────┘  │    │  └─────────────────┘  │       │
│  └───────────────────────┘    └───────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Subnet Configuration

#### Public Subnets (for ALB)

**Characteristics:**
- Route table with route to Internet Gateway (0.0.0.0/0 → IGW)
- Minimum /27 CIDR block (32 IPs) per subnet
- At least 8 free IP addresses required per subnet
- Deployed in at least 2 Availability Zones for high availability
- Auto-assign public IPv4 addresses: Disabled (ALB receives its own IPs)

**Purpose:**
- Host ALB nodes only
- Provide internet-facing access point
- Isolated from application instances

**Security Hardening:**
- Network ACLs to restrict traffic to ports 80/443
- No EC2 instances should be launched in public subnets
- Enable VPC Flow Logs for traffic monitoring

#### Private Subnets (for EC2 Instances)

**Characteristics:**
- No direct route to Internet Gateway
- Route to NAT Gateway for outbound internet access (0.0.0.0/0 → NAT-GW)
- Deployed in at least 2 Availability Zones (matching ALB subnets)
- Auto-assign public IPv4 addresses: Disabled
- Minimum /24 CIDR block recommended for scaling

**Purpose:**
- Host EC2 instances running nginx
- Prevent direct internet access to instances
- Enable outbound connectivity for updates and AWS API calls

**Security Hardening:**
- No public IP addresses assigned to instances
- Access instances via Systems Manager Session Manager only
- Implement VPC endpoints for AWS services to avoid NAT Gateway costs and improve security

---

### 2.3 Network Architecture Best Practices

#### Multi-AZ Deployment (Critical for HA)

**Requirements:**
- Deploy ALB across minimum 2 Availability Zones
- Deploy EC2 instances across minimum 2 Availability Zones
- Use Auto Scaling groups with cross-AZ distribution

**Benefits:**
- Fault tolerance against AZ failures
- Improved application availability (99.99%+)
- Load distribution across multiple physical locations

#### NAT Gateway Configuration

**Security Best Practices:**
- Deploy one NAT Gateway per Availability Zone for redundancy
- Place NAT Gateways in public subnets
- Associate Elastic IP addresses with NAT Gateways
- Monitor NAT Gateway metrics for traffic patterns and anomalies

**Cost Optimization Alternative:**
- Use VPC endpoints for AWS services (S3, DynamoDB, Systems Manager, CloudWatch)
- Reduces NAT Gateway data transfer costs
- Improves security by keeping traffic within AWS network

#### Subnet Sizing Guidelines

| Environment | Public Subnet Size | Private Subnet Size | Rationale |
|-------------|-------------------|---------------------|-----------|
| Development | /27 (32 IPs) | /24 (256 IPs) | Minimal footprint, room for growth |
| Staging | /26 (64 IPs) | /23 (512 IPs) | Moderate capacity for testing |
| Production | /24 (256 IPs) | /22 (1024 IPs) | Large capacity for scaling |

**IP Address Reservation:**
- AWS reserves 5 IP addresses per subnet (network, VPC router, DNS, future use, broadcast)
- Plan for Auto Scaling expansion (minimum 3x current capacity)
- Consider IP address management (IPAM) for large deployments

---

## 3. Network Access Control Lists (NACLs)

### 3.1 Purpose and Use Cases

**Network ACLs provide:**
- Subnet-level stateless firewall
- Defense-in-depth layer beyond security groups
- Protection against misconfigured security groups
- Ability to explicitly deny specific IP addresses or ranges

**When to Use NACLs:**
- Blocking known malicious IP addresses or CIDR ranges
- Implementing compliance requirements for network segmentation
- Preventing unauthorized access at the subnet boundary
- Protecting against DDoS attacks from specific sources

### 3.2 Recommended NACL Configuration

#### Public Subnet NACL (ALB Subnets)

**Inbound Rules:**

| Rule # | Type | Protocol | Port Range | Source | Allow/Deny | Purpose |
|--------|------|----------|------------|--------|------------|---------|
| 100 | HTTP | TCP | 80 | 0.0.0.0/0 | ALLOW | Public HTTP access |
| 110 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW | Public HTTPS access |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Ephemeral ports for return traffic |
| * | All | All | All | 0.0.0.0/0 | DENY | Default deny |

**Outbound Rules:**

| Rule # | Type | Protocol | Port Range | Destination | Allow/Deny | Purpose |
|--------|------|----------|------------|-------------|------------|---------|
| 100 | HTTP | TCP | 80 | 10.0.0.0/16 | ALLOW | Traffic to EC2 instances |
| 110 | HTTPS | TCP | 443 | 10.0.0.0/16 | ALLOW | Encrypted traffic to instances |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Ephemeral ports for responses |
| * | All | All | All | 0.0.0.0/0 | DENY | Default deny |

#### Private Subnet NACL (EC2 Subnets)

**Inbound Rules:**

| Rule # | Type | Protocol | Port Range | Source | Allow/Deny | Purpose |
|--------|------|----------|------------|--------|------------|---------|
| 100 | HTTP | TCP | 80 | 10.0.1.0/24 | ALLOW | Traffic from Public Subnet AZ-A |
| 110 | HTTP | TCP | 80 | 10.0.2.0/24 | ALLOW | Traffic from Public Subnet AZ-B |
| 120 | HTTPS | TCP | 443 | 10.0.1.0/24 | ALLOW | Encrypted traffic from Public Subnet AZ-A |
| 130 | HTTPS | TCP | 443 | 10.0.2.0/24 | ALLOW | Encrypted traffic from Public Subnet AZ-B |
| 140 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Ephemeral ports for return traffic |
| * | All | All | All | 0.0.0.0/0 | DENY | Default deny |

**Outbound Rules:**

| Rule # | Type | Protocol | Port Range | Destination | Allow/Deny | Purpose |
|--------|------|----------|------------|-------------|------------|---------|
| 100 | HTTP | TCP | 80 | 0.0.0.0/0 | ALLOW | Package downloads, updates |
| 110 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW | Secure package downloads, AWS APIs |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Ephemeral ports for ALB responses |
| * | All | All | All | 0.0.0.0/0 | DENY | Default deny |

### 3.3 NACL Best Practices

1. **Rule Numbering:** Leave gaps between rule numbers (e.g., 100, 110, 120) for future insertions
2. **Stateless Nature:** Remember to allow ephemeral ports (1024-65535) for return traffic
3. **Rule Evaluation:** Rules are evaluated in numerical order; first match wins
4. **Deny Rules:** Place deny rules before allow rules for the same traffic type
5. **Default NACL:** Never use the default NACL for production; create custom NACLs
6. **Testing:** Test NACL changes in non-production before applying to production

**Common NACL Mistakes:**

- Forgetting to allow ephemeral ports for return traffic
- Creating asymmetric rules (allowed inbound but denied outbound)
- Blocking AWS service access (Systems Manager, CloudWatch, S3)
- Overly restrictive rules that break legitimate traffic
- Not coordinating NACL rules with security group rules

---

## 4. IAM Roles and Instance Profiles

### 4.1 EC2 Instance IAM Role Design

**Principle:** Grant least privilege access using IAM roles attached to EC2 instances via instance profiles.

#### Minimum Required Permissions

**Base IAM Policy for nginx EC2 Instances:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:namespace": "CustomNginx"
        }
      }
    },
    {
      "Sid": "AllowCloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:REGION:ACCOUNT-ID:log-group:/aws/ec2/nginx/*"
      ]
    },
    {
      "Sid": "AllowSSMAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowEC2MessagesForSSM",
      "Effect": "Allow",
      "Action": [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowS3ConfigAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-nginx-config-bucket/config/*"
      ]
    }
  ]
}
```

#### Trust Policy for EC2 Service

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 4.2 IAM Best Practices

#### Least Privilege Implementation

1. **Start Minimal:** Begin with no permissions, add only what's needed
2. **Use IAM Access Analyzer:** Generate policies based on actual CloudTrail activity
3. **Condition Keys:** Restrict actions using condition keys (e.g., specific namespaces, resource tags)
4. **Resource-Level Permissions:** Specify exact ARNs instead of using wildcards
5. **Time-Based Access:** Use condition keys to restrict access to specific time windows

#### AWS Managed Policies to Consider

| Policy Name | Purpose | Use Case |
|-------------|---------|----------|
| AmazonSSMManagedInstanceCore | Systems Manager agent functionality | Required for Session Manager access |
| CloudWatchAgentServerPolicy | CloudWatch agent permissions | Metrics and logs collection |

**Warning:** Do NOT use the following overly permissive policies:
- `AdministratorAccess`
- `PowerUserAccess`
- Any policy with `*:*` permissions

#### Permission Boundaries

Consider using permission boundaries for additional control:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "cloudwatch:*",
        "ssm:*",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
```

### 4.3 Instance Identity and Credentials

#### IMDSv2 Enforcement (Critical)

**Requirement:** All EC2 instances MUST use Instance Metadata Service Version 2 (IMDSv2).

**Why IMDSv2:**
- Protects against SSRF vulnerabilities
- Requires session-oriented requests
- Mitigates unauthorized metadata access
- Prevents credential theft via network attacks

**Enforcement via Launch Template:**

```json
{
  "MetadataOptions": {
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 1,
    "HttpEndpoint": "enabled"
  }
}
```

**Account-Level Enforcement:**

Use AWS Config rule `ec2-imdsv2-check` or set as default for all new instances:

```bash
aws ec2 modify-instance-metadata-defaults \
  --http-tokens required \
  --region us-east-1
```

#### Credential Management

1. **Never Embed Credentials:** Do not hardcode AWS credentials in application code or user data
2. **Use IAM Roles:** Always use instance profiles for AWS API access
3. **Rotate Credentials:** If using external credentials, rotate them regularly (90 days maximum)
4. **Secrets Manager:** Store application secrets in AWS Secrets Manager, not environment variables
5. **Parameter Store:** Use Systems Manager Parameter Store for configuration data

---

## 5. Application Load Balancer Security

### 5.1 Listener Configuration

#### HTTPS Listener (Required)

**Security Requirements:**

1. **TLS Version:** Use TLS 1.2 minimum, TLS 1.3 preferred
2. **Security Policy:** Use `ELBSecurityPolicy-TLS13-1-2-2021-06` or later
3. **Certificate Management:** Use AWS Certificate Manager (ACM) for automatic renewal
4. **Certificate Validation:** Use DNS validation for automated certificate issuance
5. **Cipher Suites:** Use forward secrecy (FS) cipher suites only

**Recommended Security Policies:**

| Policy Name | TLS Versions | Forward Secrecy | FIPS Compliant | Use Case |
|-------------|--------------|-----------------|----------------|----------|
| ELBSecurityPolicy-TLS13-1-3-2021-06 | TLS 1.3 only | Yes | No | Modern clients only |
| ELBSecurityPolicy-TLS13-1-2-2021-06 | TLS 1.3, 1.2 | Yes | No | Recommended default |
| ELBSecurityPolicy-TLS13-1-2-Res-2021-06 | TLS 1.3, 1.2 (restricted) | Yes | No | High security |
| ELBSecurityPolicy-TLS-1-2-2017-01 | TLS 1.2 only | Yes | No | Legacy compatibility |
| ELBSecurityPolicy-FS-1-2-Res-2020-10 | TLS 1.2 | Yes | No | Forward secrecy focus |
| ELBSecurityPolicy-2016-08-FIPS | TLS 1.2 | Partial | Yes | Compliance requirements |

**HTTP Listener (Redirect Only):**

Configure HTTP listener (port 80) to redirect all traffic to HTTPS:

```json
{
  "Type": "redirect",
  "RedirectConfig": {
    "Protocol": "HTTPS",
    "Port": "443",
    "StatusCode": "HTTP_301"
  }
}
```

### 5.2 Security Headers

**Critical Security Headers (Configure via ALB Response Header Modification):**

```yaml
Strict-Transport-Security: "max-age=31536000; includeSubDomains; preload"
X-Content-Type-Options: "nosniff"
X-Frame-Options: "DENY"
X-XSS-Protection: "1; mode=block"
Referrer-Policy: "strict-origin-when-cross-origin"
Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
Permissions-Policy: "geolocation=(), microphone=(), camera=()"
```

**ALB Header Modification Features (Available):**

1. **Insert Response Headers:** Add security headers centrally
2. **Rename TLS Headers:** Rename ALB-generated headers (X-Amzn-TLS-*)
3. **Remove Server Header:** Disable `Server: awselb/2.0` header for reduced fingerprinting

**Implementation Example (AWS CLI):**

```bash
aws elbv2 modify-rule \
  --rule-arn arn:aws:elasticloadbalancing:region:account:listener-rule/... \
  --actions Type=forward,TargetGroupArn=... \
  --http-header-modification \
    'HeaderModifications=[{Name=Strict-Transport-Security,Value="max-age=31536000; includeSubDomains"}]'
```

### 5.3 ALB Attributes and Settings

**Required Security Attributes:**

| Attribute | Recommended Value | Purpose |
|-----------|------------------|---------|
| deletion_protection.enabled | true | Prevent accidental deletion |
| access_logs.s3.enabled | true | Audit trail and forensics |
| routing.http.drop_invalid_header_fields.enabled | true | Protect against header injection |
| routing.http.desync_mitigation_mode | defensive or strictest | Prevent HTTP desync attacks |
| routing.http2.enabled | true | Modern protocol support |
| ipv6.denial_of_service_protection.mode | auto | Protect against IPv6 DoS |

**ALB Access Logs Configuration:**

```json
{
  "AccessLogs": {
    "Enabled": true,
    "S3BucketName": "my-alb-logs-bucket",
    "S3BucketPrefix": "production-alb"
  }
}
```

**S3 Bucket Policy for ALB Access Logs:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ELB-ACCOUNT-ID:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-alb-logs-bucket/production-alb/*"
    }
  ]
}
```

### 5.4 Target Group Health Checks

**Security Considerations:**

1. **Dedicated Health Check Endpoint:** Use `/health` or `/status` instead of application endpoints
2. **Authentication:** Health check endpoints should not require authentication
3. **Minimal Information Disclosure:** Return 200 OK without sensitive data
4. **Frequency:** Balance security monitoring with performance (30-second interval recommended)
5. **Thresholds:** Set appropriate healthy/unhealthy thresholds (2/2 or 3/3)

**Health Check Configuration:**

```json
{
  "HealthCheckProtocol": "HTTP",
  "HealthCheckPath": "/health",
  "HealthCheckIntervalSeconds": 30,
  "HealthCheckTimeoutSeconds": 5,
  "HealthyThresholdCount": 2,
  "UnhealthyThresholdCount": 2,
  "Matcher": {
    "HttpCode": "200"
  }
}
```

### 5.5 Cross-Zone Load Balancing

**Security Impact:**
- Enabled by default for ALB (cannot be disabled at ALB level)
- Distributes traffic evenly across all registered targets in all enabled AZs
- Improves resilience and prevents overload of single AZ

**Recommendation:** Keep enabled for production workloads.

---

## 6. Auto Scaling Security Considerations

### 6.1 Launch Template Security Configuration

**Required Security Settings:**

```json
{
  "LaunchTemplateName": "nginx-secure-template",
  "LaunchTemplateData": {
    "ImageId": "ami-xxxxx",
    "InstanceType": "t3.medium",
    "IamInstanceProfile": {
      "Arn": "arn:aws:iam::ACCOUNT-ID:instance-profile/nginx-instance-profile"
    },
    "SecurityGroupIds": [
      "sg-xxxxx"
    ],
    "MetadataOptions": {
      "HttpTokens": "required",
      "HttpPutResponseHopLimit": 1,
      "HttpEndpoint": "enabled",
      "InstanceMetadataTags": "enabled"
    },
    "Monitoring": {
      "Enabled": true
    },
    "BlockDeviceMappings": [
      {
        "DeviceName": "/dev/xvda",
        "Ebs": {
          "VolumeSize": 20,
          "VolumeType": "gp3",
          "Encrypted": true,
          "KmsKeyId": "arn:aws:kms:REGION:ACCOUNT-ID:key/xxxxx",
          "DeleteOnTermination": true
        }
      }
    ],
    "NetworkInterfaces": [
      {
        "AssociatePublicIpAddress": false,
        "DeviceIndex": 0,
        "SubnetId": "subnet-xxxxx"
      }
    ],
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {
            "Key": "Name",
            "Value": "nginx-autoscaling-instance"
          },
          {
            "Key": "Environment",
            "Value": "production"
          }
        ]
      }
    ]
  }
}
```

### 6.2 Auto Scaling Group Configuration

**Security Best Practices:**

1. **Multi-AZ Deployment:** Distribute instances across at least 2 AZs
2. **Health Check Type:** Use ELB health checks (not just EC2 status checks)
3. **Health Check Grace Period:** Set to 300 seconds (5 minutes) for application startup
4. **Termination Policies:** Use `OldestInstance` or `OldestLaunchTemplate` to ensure updates
5. **Instance Refresh:** Enable for rolling updates with zero downtime

**Auto Scaling Group Configuration:**

```json
{
  "AutoScalingGroupName": "nginx-asg-production",
  "LaunchTemplate": {
    "LaunchTemplateId": "lt-xxxxx",
    "Version": "$Latest"
  },
  "MinSize": 2,
  "MaxSize": 10,
  "DesiredCapacity": 4,
  "HealthCheckType": "ELB",
  "HealthCheckGracePeriod": 300,
  "VPCZoneIdentifier": "subnet-xxxxx,subnet-yyyyy",
  "TargetGroupARNs": [
    "arn:aws:elasticloadbalancing:REGION:ACCOUNT-ID:targetgroup/nginx-tg/xxxxx"
  ],
  "TerminationPolicies": [
    "OldestLaunchTemplate"
  ],
  "NewInstancesProtectedFromScaleIn": false,
  "Tags": [
    {
      "Key": "Name",
      "Value": "nginx-autoscaling-instance",
      "PropagateAtLaunch": true
    }
  ]
}
```

### 6.3 Scaling Policies and Metrics

**Security Considerations:**

1. **Prevent Resource Exhaustion:** Set appropriate max size to prevent runaway scaling
2. **Monitor Scaling Events:** Alert on rapid scaling (potential DDoS indicator)
3. **Cooldown Periods:** Implement cooldowns to prevent thrashing
4. **Predictive Scaling:** Use machine learning for capacity planning

**Target Tracking Scaling Policy (Recommended):**

```json
{
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "app/my-alb/xxxxx/targetgroup/nginx-tg/xxxxx"
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }
}
```

### 6.4 Golden AMI Security Hardening

**Pre-baked AMI Requirements:**

1. **Minimal Base Image:** Start with minimal OS (Amazon Linux 2023 recommended)
2. **Security Updates:** Apply all security patches before creating AMI
3. **Remove Credentials:** Ensure no SSH keys, passwords, or secrets embedded
4. **Disable Root Login:** Prevent SSH root access
5. **CloudWatch Agent:** Pre-install and configure CloudWatch agent
6. **SSM Agent:** Ensure Systems Manager agent is installed and enabled
7. **Security Tools:** Install fail2ban, AIDE, or other security monitoring tools

**AMI Hardening Checklist:**

- [ ] Latest security patches applied
- [ ] Unnecessary packages removed
- [ ] SSH password authentication disabled
- [ ] Root login disabled
- [ ] CloudWatch agent configured
- [ ] Systems Manager agent enabled
- [ ] nginx installed and configured
- [ ] Log forwarding configured
- [ ] No secrets or credentials embedded
- [ ] IMDSv2 enforced
- [ ] Firewall rules configured (iptables/nftables)

---

## 7. Data Encryption

### 7.1 Encryption in Transit

#### ALB to Client (Internet)

**Requirements:**
- TLS 1.2 minimum, TLS 1.3 preferred
- Use ACM-managed certificates with automatic renewal
- Configure security policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`
- Enable HTTP Strict Transport Security (HSTS) header

**Certificate Management:**

1. **Use AWS Certificate Manager (ACM):**
   - Automatic certificate renewal
   - Free public SSL/TLS certificates
   - Integration with ALB
   - DNS validation for automated issuance

2. **Certificate Requirements:**
   - RSA 2048-bit minimum (RSA 4096-bit preferred)
   - ECDSA P-256 or P-384 for modern clients
   - Wildcard certificates for multiple subdomains
   - Subject Alternative Names (SANs) for additional domains

3. **Certificate Lifecycle:**
   - Automated renewal 60 days before expiration
   - Monitor certificate expiration via CloudWatch
   - Alert on renewal failures

#### ALB to EC2 Instances (Backend Encryption - Optional)

**When to Use:**
- Compliance requirements mandate end-to-end encryption
- High-security environments handling sensitive data
- Defense-in-depth strategy

**Configuration:**
- Configure nginx to listen on HTTPS (port 443)
- Use self-signed certificates or internal CA for backend
- ALB target group protocol: HTTPS
- Backend certificate validation: Optional (not recommended for self-signed)

**Trade-offs:**
- Increased CPU overhead on EC2 instances
- Slightly higher latency
- More complex configuration

**Recommendation:** For most use cases, HTTP between ALB and EC2 is acceptable since traffic remains within the VPC.

### 7.2 Encryption at Rest

#### EBS Volume Encryption (Required)

**Enforcement:**

1. **Enable EBS Encryption by Default (Account-Level):**

```bash
aws ec2 enable-ebs-encryption-by-default --region us-east-1
```

2. **Launch Template Configuration:**

```json
{
  "BlockDeviceMappings": [
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 20,
        "VolumeType": "gp3",
        "Encrypted": true,
        "KmsKeyId": "arn:aws:kms:REGION:ACCOUNT-ID:key/xxxxx",
        "DeleteOnTermination": true
      }
    }
  ]
}
```

**Encryption Key Management:**

| Option | Use Case | Key Management | Cost | Compliance |
|--------|----------|----------------|------|------------|
| AWS Managed Key (aws/ebs) | Simple deployments | AWS manages | Free | Basic |
| Customer Managed Key (CMK) | Production environments | You manage | $1/month per key + API calls | Advanced |
| CloudHSM | High security requirements | Hardware security module | High | FIPS 140-2 Level 3 |

**Customer Managed Key (CMK) Best Practices:**

1. **Key Policy:** Restrict key usage to specific IAM roles and services
2. **Key Rotation:** Enable automatic key rotation (yearly)
3. **Multi-Region Keys:** Use for disaster recovery scenarios
4. **Deletion Protection:** Set key deletion window to 30 days
5. **Audit:** Monitor key usage via CloudTrail

**Example KMS Key Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow use of the key for EBS",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "ec2.REGION.amazonaws.com"
        }
      }
    },
    {
      "Sid": "Allow Auto Scaling to use the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      },
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:CreateGrant"
      ],
      "Resource": "*"
    }
  ]
}
```

#### nginx Configuration and Logs

**Sensitive Data Protection:**

1. **Configuration Files:**
   - Store in S3 with encryption enabled (AES-256 or KMS)
   - Use S3 bucket policies to restrict access
   - Version control for audit trail

2. **Log Files:**
   - Forward to CloudWatch Logs (encrypted at rest by default)
   - Use CloudWatch Logs encryption with CMK for additional control
   - Retain logs for minimum 90 days (compliance requirements)

3. **Application Secrets:**
   - Store in AWS Secrets Manager (encrypted with KMS)
   - Rotate secrets automatically (90-day maximum)
   - Use IAM policies to restrict access

---

## 8. Monitoring and Logging

### 8.1 CloudWatch Metrics

#### ALB Metrics (Critical)

**Monitor These Metrics:**

| Metric | Threshold | Alert Condition | Severity |
|--------|-----------|-----------------|----------|
| TargetResponseTime | 1 second | > 1s for 5 minutes | Warning |
| UnHealthyHostCount | 0 | > 0 for 2 minutes | Critical |
| HTTPCode_Target_4XX_Count | Baseline + 50% | Spike indicates errors | Warning |
| HTTPCode_Target_5XX_Count | 0 | > 10 in 5 minutes | Critical |
| HTTPCode_ELB_5XX_Count | 0 | > 0 in 1 minute | Critical |
| RejectedConnectionCount | 0 | > 0 | Warning |
| ActiveConnectionCount | Baseline | Unusual spike (DDoS) | Warning |
| RequestCount | Baseline | Unusual spike (DDoS) | Warning |

#### EC2 Metrics (Critical)

| Metric | Threshold | Alert Condition | Severity |
|--------|-----------|-----------------|----------|
| CPUUtilization | 80% | > 80% for 10 minutes | Warning |
| StatusCheckFailed | 0 | > 0 for 2 minutes | Critical |
| NetworkIn | Baseline | Unusual spike (DDoS) | Warning |
| DiskReadOps | Baseline | Anomaly detection | Warning |
| DiskWriteOps | Baseline | Anomaly detection | Warning |

#### Custom nginx Metrics

**Recommended Custom Metrics:**

```bash
# Example: Push custom metrics to CloudWatch
aws cloudwatch put-metric-data \
  --namespace CustomNginx \
  --metric-name ActiveConnections \
  --value $(nginx -T 2>&1 | grep -oP 'Active connections: \K\d+') \
  --dimensions Instance=$(ec2-metadata --instance-id)
```

**Key nginx Metrics to Monitor:**
- Active connections
- Requests per second
- Upstream response time
- SSL/TLS handshake failures
- HTTP status code distribution
- Cache hit ratio

### 8.2 Logging Configuration

#### CloudWatch Logs

**Required Log Groups:**

1. **ALB Access Logs** (S3-based):
   - Bucket: `s3://my-alb-logs-bucket/`
   - Retention: 90 days minimum (compliance)
   - Lifecycle: Archive to Glacier after 90 days

2. **EC2 System Logs** (CloudWatch Logs):
   - Log Group: `/aws/ec2/nginx/system`
   - Streams: `/var/log/messages`, `/var/log/secure`
   - Retention: 90 days

3. **nginx Access Logs**:
   - Log Group: `/aws/ec2/nginx/access`
   - Format: JSON for easier parsing
   - Retention: 90 days

4. **nginx Error Logs**:
   - Log Group: `/aws/ec2/nginx/error`
   - Retention: 90 days

**CloudWatch Agent Configuration:**

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/nginx/access",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/ec2/nginx/error",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/nginx/system",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CustomNginx",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

#### VPC Flow Logs (Required)

**Purpose:**
- Network traffic monitoring
- Security incident investigation
- Compliance auditing
- Anomaly detection

**Configuration:**

```json
{
  "ResourceType": "VPC",
  "ResourceIds": ["vpc-xxxxx"],
  "TrafficType": "ALL",
  "LogDestinationType": "cloud-watch-logs",
  "LogGroupName": "/aws/vpc/flowlogs",
  "DeliverLogsPermissionArn": "arn:aws:iam::ACCOUNT-ID:role/vpc-flow-logs-role",
  "LogFormat": "${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}"
}
```

**VPC Flow Logs Best Practices:**

1. **Enable for All VPCs:** Production, staging, and development
2. **Log All Traffic:** Accepted, rejected, and all traffic
3. **Custom Format:** Include fields relevant to security analysis
4. **Retention:** 90 days minimum
5. **Analysis:** Use CloudWatch Logs Insights or Athena for querying

#### CloudTrail (Required)

**Purpose:**
- API call auditing
- Compliance documentation
- Security investigation
- Change tracking

**Configuration:**

```json
{
  "Name": "production-cloudtrail",
  "S3BucketName": "my-cloudtrail-logs-bucket",
  "IncludeGlobalServiceEvents": true,
  "IsMultiRegionTrail": true,
  "EnableLogFileValidation": true,
  "KmsKeyId": "arn:aws:kms:REGION:ACCOUNT-ID:key/xxxxx",
  "EventSelectors": [
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": true,
      "DataResources": [
        {
          "Type": "AWS::S3::Object",
          "Values": ["arn:aws:s3:::my-nginx-config-bucket/*"]
        }
      ]
    }
  ]
}
```

**CloudTrail Best Practices:**

1. **Enable in All Regions:** Capture activity across entire account
2. **Log File Validation:** Detect tampering with CloudTrail logs
3. **Encryption:** Use KMS CMK for CloudTrail log encryption
4. **S3 Bucket Security:** Enable versioning, MFA delete, and block public access
5. **CloudWatch Alarms:** Alert on critical API calls (e.g., security group changes, IAM modifications)

### 8.3 Security Monitoring and Alerting

#### CloudWatch Alarms

**Critical Security Alarms:**

1. **Unauthorized API Calls:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "UnauthorizedAPICalls" \
  --metric-name UnauthorizedAPICalls \
  --namespace CloudTrailMetrics \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:REGION:ACCOUNT-ID:security-alerts
```

2. **Security Group Changes:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "SecurityGroupChanges" \
  --metric-name SecurityGroupEventCount \
  --namespace CloudTrailMetrics \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:REGION:ACCOUNT-ID:security-alerts
```

3. **Root Account Usage:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "RootAccountUsage" \
  --metric-name RootAccountUsageCount \
  --namespace CloudTrailMetrics \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:REGION:ACCOUNT-ID:security-alerts
```

#### GuardDuty (Recommended)

**Purpose:**
- Intelligent threat detection
- Continuous monitoring of AWS accounts and workloads
- Machine learning-based anomaly detection
- Automated security findings

**Enable GuardDuty:**

```bash
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES
```

**GuardDuty Findings to Monitor:**
- UnauthorizedAccess:EC2/SSHBruteForce
- Recon:EC2/PortProbeUnprotectedPort
- Trojan:EC2/DNSDataExfiltration
- UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration

#### AWS Security Hub (Recommended)

**Purpose:**
- Centralized security findings aggregation
- Continuous compliance checking
- Security posture assessment
- Integration with GuardDuty, Inspector, Macie

**Enable Security Hub:**

```bash
aws securityhub enable-security-hub \
  --enable-default-standards
```

**Standards to Enable:**
- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark
- PCI DSS (if applicable)

### 8.4 Log Analysis and Retention

#### CloudWatch Logs Insights Queries

**Example: Detect Failed nginx Requests:**

```sql
fields @timestamp, status, request, remote_addr
| filter status >= 400
| sort @timestamp desc
| limit 100
```

**Example: Detect Suspicious Traffic Patterns:**

```sql
fields @timestamp, remote_addr, status
| stats count() by remote_addr, status
| filter count > 100
| sort count desc
```

**Example: Monitor SSL/TLS Errors:**

```sql
fields @timestamp, ssl_protocol, ssl_cipher
| filter @message like /SSL/
| stats count() by ssl_protocol, ssl_cipher
```

#### Log Retention Policy

| Log Type | Retention Period | Archive Location | Purpose |
|----------|-----------------|------------------|---------|
| ALB Access Logs | 90 days (active) | S3 Glacier (7 years) | Compliance, forensics |
| CloudWatch Logs | 90 days | S3 (optional) | Troubleshooting, analysis |
| VPC Flow Logs | 90 days | S3 (optional) | Security investigation |
| CloudTrail | 90 days (active) | S3 (7 years) | Compliance, audit |

**S3 Lifecycle Policy for Log Archival:**

```json
{
  "Rules": [
    {
      "Id": "ArchiveALBLogs",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
```

---

## 9. Compliance and Governance

### 9.1 AWS Config Rules

**Deploy These Config Rules:**

1. **EC2 Instance IMDSv2 Check:**
   - Rule: `ec2-imdsv2-check`
   - Ensures all instances use IMDSv2

2. **EBS Encryption Enabled:**
   - Rule: `encrypted-volumes`
   - Verifies all EBS volumes are encrypted

3. **Security Group Ingress Rules:**
   - Rule: `restricted-ssh`
   - Prevents SSH access from 0.0.0.0/0

4. **VPC Flow Logs Enabled:**
   - Rule: `vpc-flow-logs-enabled`
   - Ensures VPC Flow Logs are active

5. **CloudTrail Enabled:**
   - Rule: `cloud-trail-enabled`
   - Verifies CloudTrail is logging

**Automated Remediation:**

Use AWS Config with Systems Manager Automation to automatically remediate non-compliant resources.

**Example: Auto-Remediate Unencrypted EBS Volumes:**

```json
{
  "ConfigRuleName": "encrypted-volumes",
  "RemediationConfiguration": {
    "TargetType": "SSM_DOCUMENT",
    "TargetIdentifier": "AWS-EnableEBSEncryptionByDefault",
    "Automatic": true,
    "MaximumAutomaticAttempts": 5,
    "RetryAttemptSeconds": 60
  }
}
```

### 9.2 Service Control Policies (SCPs)

**Organizational Controls:**

If using AWS Organizations, implement SCPs to enforce security policies across all accounts.

**Example SCP: Prevent IMDSv1 Usage:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:MetadataHttpTokens": "required"
        }
      }
    }
  ]
}
```

**Example SCP: Enforce EBS Encryption:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:volume/*",
      "Condition": {
        "Bool": {
          "ec2:Encrypted": "false"
        }
      }
    }
  ]
}
```

### 9.3 Compliance Frameworks

#### CIS AWS Foundations Benchmark

**Key Requirements for This Architecture:**

- [ ] 1.4 - Ensure access keys are rotated every 90 days
- [ ] 2.1.1 - Ensure S3 bucket access logging is enabled
- [ ] 2.3.1 - Ensure VPC flow logging is enabled in all VPCs
- [ ] 4.1 - Ensure no security groups allow ingress from 0.0.0.0/0 to port 22
- [ ] 4.2 - Ensure no security groups allow ingress from 0.0.0.0/0 to port 3389
- [ ] 4.3 - Ensure the default security group restricts all traffic
- [ ] 5.1 - Ensure CloudTrail is enabled in all regions

#### PCI DSS (Payment Card Industry)

**Relevant Requirements:**

- Requirement 1: Install and maintain firewall configuration (Security Groups, NACLs)
- Requirement 2: Do not use vendor-supplied defaults (Change default passwords, disable root access)
- Requirement 4: Encrypt transmission of cardholder data (TLS 1.2+)
- Requirement 8: Identify and authenticate access (IAM roles, MFA)
- Requirement 10: Track and monitor all access (CloudTrail, VPC Flow Logs, Access Logs)

#### HIPAA (Health Insurance Portability and Accountability Act)

**Security Rule Requirements:**

- Access Control: IAM roles with least privilege
- Audit Controls: CloudTrail, VPC Flow Logs, ALB access logs
- Integrity: Log file validation, encryption
- Transmission Security: TLS 1.2+ for all data in transit

---

## 10. Incident Response and Security Operations

### 10.1 Security Incident Response Plan

**Phases:**

1. **Preparation:**
   - Document incident response procedures
   - Assign security incident response team (SIRT)
   - Configure CloudWatch alarms and SNS notifications
   - Enable GuardDuty and Security Hub

2. **Detection and Analysis:**
   - Monitor GuardDuty findings
   - Review Security Hub compliance scores
   - Analyze CloudTrail logs for suspicious activity
   - Investigate CloudWatch alarms

3. **Containment:**
   - Isolate compromised instances (change security groups)
   - Revoke IAM credentials if compromised
   - Block malicious IPs via NACLs
   - Enable AWS WAF if under attack

4. **Eradication:**
   - Terminate compromised instances
   - Rotate all credentials and keys
   - Patch vulnerabilities
   - Update security groups and NACLs

5. **Recovery:**
   - Launch new instances from clean AMI
   - Restore data from backups
   - Verify system integrity
   - Monitor for residual threats

6. **Lessons Learned:**
   - Document incident timeline
   - Update incident response procedures
   - Implement preventive controls
   - Conduct post-incident review

### 10.2 Security Automation

**AWS Systems Manager Automation Documents:**

1. **Isolate Compromised Instance:**

```yaml
schemaVersion: '0.3'
assumeRole: '{{ AutomationAssumeRole }}'
parameters:
  InstanceId:
    type: String
mainSteps:
  - name: IsolateInstance
    action: 'aws:executeAwsApi'
    inputs:
      Service: ec2
      Api: ModifyInstanceAttribute
      InstanceId: '{{ InstanceId }}'
      Groups:
        - sg-quarantine-xxxxx
```

2. **Revoke IAM Credentials:**

```yaml
schemaVersion: '0.3'
assumeRole: '{{ AutomationAssumeRole }}'
parameters:
  UserName:
    type: String
mainSteps:
  - name: DeactivateAccessKeys
    action: 'aws:executeAwsApi'
    inputs:
      Service: iam
      Api: UpdateAccessKey
      UserName: '{{ UserName }}'
      AccessKeyId: '{{ AccessKeyId }}'
      Status: Inactive
```

### 10.3 Backup and Disaster Recovery

#### EBS Snapshots

**Backup Strategy:**

- **Frequency:** Daily automated snapshots via AWS Backup or Data Lifecycle Manager
- **Retention:** 7 daily, 4 weekly, 12 monthly snapshots
- **Encryption:** All snapshots encrypted with KMS
- **Cross-Region Replication:** Copy snapshots to secondary region for DR

**AWS Backup Configuration:**

```json
{
  "BackupPlan": {
    "BackupPlanName": "nginx-daily-backup",
    "Rules": [
      {
        "RuleName": "DailyBackup",
        "TargetBackupVault": "Default",
        "ScheduleExpression": "cron(0 2 * * ? *)",
        "StartWindowMinutes": 60,
        "CompletionWindowMinutes": 120,
        "Lifecycle": {
          "DeleteAfterDays": 7
        }
      }
    ]
  },
  "BackupSelection": {
    "SelectionName": "nginx-instances",
    "IamRoleArn": "arn:aws:iam::ACCOUNT-ID:role/AWSBackupRole",
    "Resources": [
      "arn:aws:ec2:*:*:volume/*"
    ],
    "ListOfTags": [
      {
        "ConditionType": "STRINGEQUALS",
        "ConditionKey": "Backup",
        "ConditionValue": "true"
      }
    ]
  }
}
```

#### Application-Level Backups

**nginx Configuration Backup:**

- Store nginx configurations in S3 with versioning enabled
- Use Git for version control of configuration files
- Automate configuration backups via cron or AWS Backup

**Recovery Time Objective (RTO) and Recovery Point Objective (RPO):**

| Tier | RTO | RPO | Strategy |
|------|-----|-----|----------|
| Production | < 1 hour | < 15 minutes | Multi-AZ Auto Scaling, automated snapshots |
| Staging | < 4 hours | < 1 hour | Single-AZ Auto Scaling, daily snapshots |
| Development | < 24 hours | < 24 hours | Manual recovery, weekly snapshots |

---

## 11. Summary of Critical Security Controls

### 11.1 Mandatory Security Requirements

**Must Implement (Critical Priority):**

1. **Network Security:**
   - ✅ EC2 instances in private subnets only (no public IPs)
   - ✅ Security groups with least privilege (reference SG IDs, not 0.0.0.0/0)
   - ✅ Multi-AZ deployment for high availability
   - ✅ VPC Flow Logs enabled on all VPCs

2. **Encryption:**
   - ✅ TLS 1.2+ on ALB with ACM certificates
   - ✅ EBS encryption enabled by default (account-level)
   - ✅ All EBS volumes encrypted with KMS CMK
   - ✅ CloudTrail logs encrypted with KMS

3. **IAM and Access Control:**
   - ✅ IMDSv2 enforced on all EC2 instances
   - ✅ IAM roles with least privilege policies
   - ✅ No hardcoded credentials in code or user data
   - ✅ Systems Manager Session Manager for instance access (no SSH from internet)

4. **Logging and Monitoring:**
   - ✅ CloudTrail enabled in all regions with log file validation
   - ✅ VPC Flow Logs enabled for all VPCs
   - ✅ ALB access logs stored in S3
   - ✅ CloudWatch Logs for application and system logs
   - ✅ CloudWatch alarms for critical metrics and security events

5. **Auto Scaling Security:**
   - ✅ Launch templates with security hardening (no public IPs, encrypted EBS, IMDSv2)
   - ✅ ELB health checks enabled
   - ✅ Minimum 2 instances across 2 AZs
   - ✅ Golden AMI with security patches and hardening

**Should Implement (High Priority):**

- GuardDuty enabled for threat detection
- Security Hub enabled for compliance monitoring
- AWS Config rules for automated compliance checking
- Automated backups via AWS Backup
- Security headers configured on ALB
- Network ACLs for additional subnet-level protection

**Consider Implementing (Medium Priority):**

- AWS WAF on ALB for application-level protection
- AWS Shield Advanced for DDoS protection
- VPC endpoints for AWS services (reduce NAT Gateway costs)
- Backend encryption (ALB to EC2) for defense-in-depth
- AWS Firewall Manager for centralized security policy management

### 11.2 Security Checklist

**Pre-Deployment Checklist:**

- [ ] EC2 instances deployed in private subnets (no public IPs)
- [ ] Security groups configured with least privilege
- [ ] Multi-AZ deployment for ALB and Auto Scaling group
- [ ] TLS 1.2+ configured on ALB with ACM certificate
- [ ] EBS encryption enabled by default (account-level)
- [ ] Launch template enforces IMDSv2
- [ ] IAM instance profile with least privilege policies
- [ ] CloudTrail enabled in all regions
- [ ] VPC Flow Logs enabled
- [ ] ALB access logs enabled and stored in S3
- [ ] CloudWatch agent configured on EC2 instances
- [ ] CloudWatch alarms configured for critical metrics
- [ ] Systems Manager Session Manager configured for instance access
- [ ] Golden AMI created with security hardening
- [ ] Backup strategy implemented (AWS Backup or snapshots)
- [ ] Security headers configured on ALB
- [ ] Network ACLs configured (if required)
- [ ] AWS Config rules deployed for compliance monitoring
- [ ] GuardDuty enabled
- [ ] Security Hub enabled

**Post-Deployment Validation:**

- [ ] Verify no EC2 instances have public IPs
- [ ] Confirm SSH/RDP ports not accessible from internet
- [ ] Test HTTPS access via ALB
- [ ] Verify HTTP to HTTPS redirect works
- [ ] Confirm EBS volumes are encrypted
- [ ] Test Systems Manager Session Manager access
- [ ] Review CloudTrail logs for deployment activities
- [ ] Check VPC Flow Logs are being generated
- [ ] Verify CloudWatch metrics are being collected
- [ ] Test Auto Scaling scale-out and scale-in
- [ ] Simulate instance failure and verify recovery
- [ ] Review GuardDuty findings (should be minimal/none)
- [ ] Check Security Hub compliance score

---

## 12. References and Additional Resources

### AWS Documentation

- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [AWS Foundational Security Best Practices](https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html)
- [Amazon EC2 Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html)
- [Application Load Balancer Security](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)
- [VPC Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [Instance Metadata Service Version 2 (IMDSv2)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Amazon EBS Encryption](https://docs.aws.amazon.com/ebs/latest/userguide/how-ebs-encryption-works.html)

### Compliance and Frameworks

- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [PCI DSS on AWS](https://aws.amazon.com/compliance/pci-dss-level-1-faqs/)
- [HIPAA Compliance on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [SOC 2 Compliance](https://aws.amazon.com/compliance/soc-faqs/)

### Security Tools

- [Amazon GuardDuty](https://aws.amazon.com/guardduty/)
- [AWS Security Hub](https://aws.amazon.com/security-hub/)
- [AWS Config](https://aws.amazon.com/config/)
- [AWS CloudTrail](https://aws.amazon.com/cloudtrail/)
- [Amazon Inspector](https://aws.amazon.com/inspector/)

---

## Document Metadata

- **Version:** 1.0
- **Last Updated:** 2025-01-06
- **Author:** AWS Security Advisor
- **Classification:** Public
- **Review Cycle:** Quarterly

**Change Log:**

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-06 | 1.0 | Initial comprehensive security analysis |

---

**End of Document**
