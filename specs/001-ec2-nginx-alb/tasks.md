# Tasks: EC2 Nginx Web Server with Application Load Balancer

**Input**: Design documents from `/specs/001-ec2-nginx-alb/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

**Tests**: No tests explicitly requested in specification - focusing on infrastructure deployment and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Terraform infrastructure project with files at repository root:
- `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `versions.tf`, `locals.tf`
- `override.tf`, `sandbox.auto.tfvars`, `sandbox.auto.tfvars.example`
- `.gitignore`, `.pre-commit-config.yaml`, `README.md`

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Initialize Terraform project structure and configuration management

- [ ] T001 Create Terraform project structure per plan.md at repository root
- [ ] T002 [P] Create .gitignore file excluding .terraform/, *.tfstate, *.tfstate.backup, .terraform.lock.hcl, *.tfvars
- [ ] T003 [P] Create versions.tf with Terraform >= 1.8 and AWS provider ~> 6.19 constraints
- [ ] T004 [P] Create providers.tf with AWS provider configuration for ap-southeast-2
- [ ] T005 [P] Create locals.tf with common tags (Environment, Project, ManagedBy) configuration
- [ ] T006 [P] Create variables.tf skeleton with variable declarations (to be populated in foundational phase)
- [ ] T007 [P] Create outputs.tf skeleton with output declarations (to be populated per user story)
- [ ] T008 Get GitHub repository name for HCP Terraform workspace naming
- [ ] T009 Create override.tf with HCP Terraform cloud backend configuration (organization: hashi-demos-apj, project: sandbox, workspace: sandbox_<GITHUB_REPO_NAME>)
- [ ] T010 [P] Create sandbox.auto.tfvars.example with template variable values and documentation
- [ ] T011 [P] Initialize pre-commit framework and install hooks
- [ ] T012 [P] Verify .pre-commit-config.yaml exists with terraform_fmt, terraform_validate, terraform_docs, tflint, checkov hooks

**Checkpoint**: Project structure ready - foundational infrastructure can now be defined

---

## Phase 2: Foundational (Core Networking)

**Purpose**: Network foundation that ALL user stories depend on (VPC, subnets, security groups)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T013 Define region variable in variables.tf (type: string, description, default: ap-southeast-2)
- [ ] T014 [P] Define availability_zones variable in variables.tf (type: list(string), description, default: ["ap-southeast-2a", "ap-southeast-2b"])
- [ ] T015 [P] Define vpc_cidr variable in variables.tf (type: string, description, default: 10.0.0.0/16, validation rule)
- [ ] T016 [P] Define public_subnets variable in variables.tf (type: list(string), description, default: ["10.0.1.0/24", "10.0.2.0/24"])
- [ ] T017 [P] Define private_subnets variable in variables.tf (type: list(string), description, default: ["10.0.11.0/24", "10.0.12.0/24"])
- [ ] T018 [P] Define enable_nat_gateway variable in variables.tf (type: bool, description, default: true)
- [ ] T019 [P] Define single_nat_gateway variable in variables.tf (type: bool, description, default: true for cost optimization)
- [ ] T020 [P] Define environment variable in variables.tf (type: string, description, validation: sandbox/dev/staging/prod)
- [ ] T021 [P] Define project_name variable in variables.tf (type: string, description)
- [ ] T022 Add common_tags local in locals.tf combining environment, project_name, ManagedBy: Terraform
- [ ] T023 Add data source for AWS availability zones in main.tf
- [ ] T024 Add VPC module declaration in main.tf using hashi-demos-apj/vpc/aws version ~> 6.5.0 (implements FR-001, FR-006)
- [ ] T025 Configure VPC module inputs in main.tf: name, cidr, azs, public_subnets, private_subnets, enable_nat_gateway, single_nat_gateway, enable_dns_hostnames: true, enable_dns_support: true, tags
- [ ] T026 [P] Add VPC outputs to outputs.tf: vpc_id, vpc_arn, vpc_cidr_block (reference module.vpc.*)
- [ ] T027 [P] Add subnet outputs to outputs.tf: public_subnet_ids, private_subnet_ids (reference module.vpc.*)
- [ ] T028 [P] Add gateway outputs to outputs.tf: nat_gateway_ids, nat_gateway_public_ips, internet_gateway_id (reference module.vpc.*)
- [ ] T029 Populate sandbox.auto.tfvars with foundational variable values: region, availability_zones, vpc_cidr, subnets, environment, project_name
- [ ] T030 Run terraform init to initialize backend and download modules
- [ ] T031 Run terraform validate to verify configuration syntax
- [ ] T032 Run terraform fmt -recursive to format all .tf files
- [ ] T033 Commit foundational infrastructure: "Add VPC and networking foundation (FR-001, FR-006)"

**Checkpoint**: Network foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Deploy Nginx Web Server Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Provision working web server infrastructure with EC2 instances running nginx, accessible via instance public IPs (minimal viable infrastructure)

**Independent Test**: Deploy infrastructure, access EC2 instance via public IP, receive nginx welcome page via HTTP

### Implementation for User Story 1

- [ ] T034 [P] [US1] Define instance_type variable in variables.tf (type: string, description, default: t3.micro)
- [ ] T035 [P] [US1] Define ami_id variable in variables.tf (type: string, description, default: empty string for data source lookup)
- [ ] T036 [P] [US1] Define key_name variable in variables.tf (type: string, description, optional for SSH access)
- [ ] T037 [US1] Add data source for latest Amazon Linux 2023 AMI in main.tf using AWS SSM parameter
- [ ] T038 [US1] Create nginx user data script as local value in locals.tf (implements FR-002, FR-003)
- [ ] T039 [US1] Add EC2 security group allowing HTTP (port 80) from 0.0.0.0/0 and HTTPS outbound in main.tf (implements FR-009 temporarily - will be restricted in US2)
- [ ] T040 [US1] Add EC2 instance module declaration in main.tf using hashi-demos-apj/ec2-instance/aws version ~> 6.1.4 (implements FR-001, FR-002)
- [ ] T041 [US1] Configure EC2 module inputs in main.tf: name, ami (from data source), instance_type, subnet_id (first private subnet), vpc_security_group_ids, user_data, create_iam_instance_profile: true, iam_role_policy_arns: [AmazonSSMManagedInstanceCore], metadata_options (IMDSv2 enforcement), tags
- [ ] T042 [P] [US1] Add EC2 outputs to outputs.tf: instance_id, instance_private_ip, instance_public_ip (for initial testing) (implements FR-014 partially)
- [ ] T043 [US1] Update sandbox.auto.tfvars with US1 variable values: instance_type, key_name (if needed)
- [ ] T044 [US1] Run terraform validate to verify US1 configuration
- [ ] T045 [US1] Run terraform fmt -recursive to format files
- [ ] T046 [US1] Commit US1 implementation: "Add EC2 instance with nginx (FR-001, FR-002, FR-003, US1)"
- [ ] T047 [US1] Push feature branch to remote repository
- [ ] T048 [US1] Configure HCP Terraform credentials (~/.terraform.d/credentials.tfrc.json)
- [ ] T049 [US1] Run terraform init to ensure backend is configured
- [ ] T050 [US1] Run terraform plan locally to preview changes
- [ ] T051 [US1] Test nginx accessibility: curl http://<instance-public-ip> (validate FR-002, FR-003 working)

**Checkpoint**: At this point, User Story 1 should be fully functional - basic nginx web server running on EC2

---

## Phase 4: User Story 2 - Enable Load Balancing and High Availability (Priority: P2)

**Goal**: Add Application Load Balancer distributing traffic across multiple EC2 instances in multiple availability zones

**Independent Test**: Deploy ALB, verify traffic distribution to backend instances, confirm health checks passing, access via ALB DNS endpoint

### Implementation for User Story 2

- [ ] T052 [P] [US2] Define alb_name variable in variables.tf (type: string, description)
- [ ] T053 [P] [US2] Define enable_deletion_protection variable in variables.tf (type: bool, description, default: false for ephemeral)
- [ ] T054 [P] [US2] Define health_check_path variable in variables.tf (type: string, description, default: /health)
- [ ] T055 [P] [US2] Define health_check_interval variable in variables.tf (type: number, description, default: 30)
- [ ] T056 [P] [US2] Define health_check_timeout variable in variables.tf (type: number, description, default: 5)
- [ ] T057 [P] [US2] Define healthy_threshold variable in variables.tf (type: number, description, default: 2)
- [ ] T058 [P] [US2] Define unhealthy_threshold variable in variables.tf (type: number, description, default: 3)
- [ ] T059 [P] [US2] Define deregistration_delay variable in variables.tf (type: number, description, default: 30)
- [ ] T060 [US2] Remove EC2 instance module from main.tf (will be replaced by Auto Scaling Group in US3)
- [ ] T061 [US2] Create temporary EC2 instances (count: 2) directly in main.tf across both AZs for US2 testing before ASG (implements FR-006 multi-AZ)
- [ ] T062 [US2] Update EC2 security group in main.tf: remove 0.0.0.0/0 ingress, add ALB security group as source (implements FR-010)
- [ ] T063 [US2] Add ALB module declaration in main.tf using hashi-demos-apj/alb/aws version ~> 10.1.0 (implements FR-004, FR-005)
- [ ] T064 [US2] Configure ALB module inputs in main.tf: name, load_balancer_type: application, vpc_id, subnets (public), security_groups (creates SG allowing port 80 from 0.0.0.0/0), internal: false, enable_deletion_protection, tags (implements FR-009)
- [ ] T065 [US2] Configure ALB listeners in main.tf: HTTP listener port 80 forwarding to target group
- [ ] T066 [US2] Configure target group in main.tf: port 80, protocol HTTP, target_type: instance, health_check configuration (implements FR-007)
- [ ] T067 [US2] Attach EC2 instances to target group using target_group_arns (implements FR-005, FR-008)
- [ ] T068 [P] [US2] Add ALB outputs to outputs.tf: alb_arn, alb_dns_name (primary access point), alb_zone_id, target_group_arn (implements FR-014)
- [ ] T069 [P] [US2] Remove instance_public_ip output from outputs.tf (no longer needed - access via ALB)
- [ ] T070 [US2] Update nginx user data in locals.tf to create /health endpoint (implements FR-007)
- [ ] T071 [US2] Update sandbox.auto.tfvars with US2 variable values: alb_name, health check parameters
- [ ] T072 [US2] Run terraform validate to verify US2 configuration
- [ ] T073 [US2] Run terraform fmt -recursive to format files
- [ ] T074 [US2] Commit US2 implementation: "Add ALB with multi-AZ HA (FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, FR-010, US2)"
- [ ] T075 [US2] Push feature branch to remote repository
- [ ] T076 [US2] Run terraform plan to preview US2 changes
- [ ] T077 [US2] Test ALB endpoint: curl http://<alb-dns-name> (validate FR-005, FR-014 working)
- [ ] T078 [US2] Test health endpoint: curl http://<alb-dns-name>/health (validate FR-007 working)
- [ ] T079 [US2] Verify target health in AWS Console (validate FR-008 working)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - ALB distributing traffic to multiple instances

---

## Phase 5: User Story 3 - Auto-Scale Infrastructure Based on Demand (Priority: P3)

**Goal**: Replace static EC2 instances with Auto Scaling Group that automatically scales based on CPU utilization

**Independent Test**: Configure ASG, verify instances scale up when CPU > 50%, scale down when CPU < 50%, ALB health checks integrated

### Implementation for User Story 3

- [ ] T080 [P] [US3] Define min_size variable in variables.tf (type: number, description, default: 2)
- [ ] T081 [P] [US3] Define max_size variable in variables.tf (type: number, description, default: 4)
- [ ] T082 [P] [US3] Define desired_capacity variable in variables.tf (type: number, description, default: 2)
- [ ] T083 [P] [US3] Define health_check_grace_period variable in variables.tf (type: number, description, default: 300)
- [ ] T084 [P] [US3] Define cpu_target_value variable in variables.tf (type: number, description, default: 50.0)
- [ ] T085 [P] [US3] Define instance_warmup variable in variables.tf (type: number, description, default: 300)
- [ ] T086 [US3] Remove temporary EC2 instances (count: 2) from main.tf added in US2
- [ ] T087 [US3] Add Auto Scaling Group module declaration in main.tf using hashi-demos-apj/autoscaling/aws version ~> 9.0.2 (implements FR-011)
- [ ] T088 [US3] Configure ASG module inputs in main.tf: name, min_size, max_size, desired_capacity, vpc_zone_identifier (private subnets), health_check_type: ELB, health_check_grace_period, create_launch_template: true, tags
- [ ] T089 [US3] Configure launch template in main.tf: image_id (from data source), instance_type, user_data, security_groups (EC2 SG), iam_instance_profile (create with SSM policy), metadata_options (IMDSv2), block_device_mappings (EBS encryption), tags
- [ ] T090 [US3] Configure target group attachment in main.tf: attach ASG to ALB target group (replaces manual attachment from US2)
- [ ] T091 [US3] Configure target tracking scaling policy in main.tf: metric type ASGAverageCPUUtilization, target_value, estimated_instance_warmup (implements FR-011 scaling behavior)
- [ ] T092 [P] [US3] Add ASG outputs to outputs.tf: autoscaling_group_id, autoscaling_group_name, autoscaling_group_arn, launch_template_id
- [ ] T093 [P] [US3] Add IAM outputs to outputs.tf: iam_role_arn, iam_instance_profile_arn
- [ ] T094 [US3] Update sandbox.auto.tfvars with US3 variable values: min_size, max_size, desired_capacity, scaling parameters
- [ ] T095 [US3] Run terraform validate to verify US3 configuration
- [ ] T096 [US3] Run terraform fmt -recursive to format files
- [ ] T097 [US3] Commit US3 implementation: "Add Auto Scaling Group with CPU-based scaling (FR-011, US3)"
- [ ] T098 [US3] Push feature branch to remote repository
- [ ] T099 [US3] Run terraform plan to preview US3 changes
- [ ] T100 [US3] Verify ASG instances launching and registering with ALB target group
- [ ] T101 [US3] Test ALB access still working: curl http://<alb-dns-name>
- [ ] T102 [US3] Monitor ASG scaling behavior via CloudWatch metrics

**Checkpoint**: All user stories should now be independently functional - complete auto-scaling infrastructure

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, testing, and production readiness

- [ ] T103 [P] Add comprehensive README.md documenting infrastructure, prerequisites, deployment, testing (will be auto-generated by terraform-docs via pre-commit)
- [ ] T104 [P] Add all resource tags using var.environment, var.project_name, and local.common_tags (implements FR-012)
- [ ] T105 [P] Review all module sources to ensure app.terraform.io/hashi-demos-apj/ prefix (implements Constitution 1.1)
- [ ] T106 [P] Review all security groups to ensure least privilege (implements FR-009, FR-010, Constitution 3.4)
- [ ] T107 [P] Verify IMDSv2 enforcement in launch template metadata_options (implements Constitution 1.3)
- [ ] T108 [P] Verify EBS encryption enabled in launch template block_device_mappings (implements Constitution 3.4)
- [ ] T109 [P] Add descriptions to all variables in variables.tf with usage guidance
- [ ] T110 [P] Add descriptions to all outputs in outputs.tf explaining their purpose
- [ ] T111 [P] Verify no hardcoded values - all configurable via variables (implements Constitution 3.4)
- [ ] T112 Run pre-commit run --all-files to execute all hooks (terraform_fmt, terraform_validate, terraform_docs, tflint, checkov)
- [ ] T113 Fix any issues identified by pre-commit hooks (security, style, documentation)
- [ ] T114 Commit polish changes: "Add documentation, tags, and security validation"
- [ ] T115 Push all changes to remote repository
- [ ] T116 Create ephemeral HCP Terraform workspace for testing: sandbox_<GITHUB_REPO_NAME>
- [ ] T117 Configure workspace variables in ephemeral workspace matching sandbox.auto.tfvars
- [ ] T118 Trigger terraform plan in ephemeral workspace via HCP Terraform CLI
- [ ] T119 Review plan output for expected resources and configuration
- [ ] T120 Apply infrastructure in ephemeral workspace (auto-apply enabled)
- [ ] T121 Validate deployment success: all resources created without errors
- [ ] T122 Test HTTP access via ALB DNS: curl http://<alb-dns-name>
- [ ] T123 Test health check endpoint: curl http://<alb-dns-name>/health
- [ ] T124 Verify target group health: all instances healthy
- [ ] T125 Verify Auto Scaling Group: desired capacity met, instances distributed across AZs
- [ ] T126 Verify Systems Manager Session Manager access to instances
- [ ] T127 Review CloudWatch metrics: ALB request count, target response time, ASG metrics
- [ ] T128 Run quickstart.md validation steps to confirm deployment guide accuracy
- [ ] T129 Destroy ephemeral workspace resources (auto-destroy will handle after 2 hours if not manual)
- [ ] T130 Create final commit with deployment log: "Complete infrastructure deployment and testing"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T012) - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (T013-T033) - No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on Foundational (T013-T033) - Builds on US1 but can be independently developed
- **User Story 3 (Phase 5)**: Depends on Foundational (T013-T033) and US2 (T052-T079) for ALB target group
- **Polish (Phase 6)**: Depends on all desired user stories being complete (T034-T102)

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Minimal viable infrastructure
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Adds ALB and HA (references US1 concepts but independent implementation)
- **User Story 3 (P3)**: Requires US2 completion - Needs ALB target group from US2 for ASG attachment

### Within Each User Story

**User Story 1 (Basic Infrastructure)**:
1. Define variables (T034-T036) - parallel
2. Add data sources and locals (T037-T038)
3. Create security group (T039)
4. Add EC2 module (T040-T041)
5. Add outputs (T042)
6. Deploy and test (T043-T051)

**User Story 2 (Load Balancing & HA)**:
1. Define variables (T052-T059) - parallel
2. Update EC2 configuration (T060-T062)
3. Add ALB module (T063-T067)
4. Add outputs (T068-T069)
5. Update user data (T070)
6. Deploy and test (T071-T079)

**User Story 3 (Auto Scaling)**:
1. Define variables (T080-T085) - parallel
2. Replace static instances with ASG (T086-T091)
3. Add outputs (T092-T093)
4. Deploy and test (T094-T102)

### Parallel Opportunities

- **Phase 1 Setup**: T002, T003, T004, T005, T006, T007, T010, T011, T012 can run in parallel (different files)
- **Phase 2 Foundational**: T014-T021 (variable definitions), T026-T028 (outputs) can run in parallel within their groups
- **Phase 3 US1**: T034-T036 (variables), T042 (outputs) can run in parallel
- **Phase 4 US2**: T052-T059 (variables), T068-T069 (outputs) can run in parallel
- **Phase 5 US3**: T080-T085 (variables), T092-T093 (outputs) can run in parallel
- **Phase 6 Polish**: T103-T111 (documentation and validation) can run in parallel

**Team Parallelization**:
- Once Foundational (Phase 2) completes, different team members could theoretically work on US1, US2, US3 in parallel
- However, US3 requires US2's ALB target group, so sequential implementation (US1 → US2 → US3) is recommended

---

## Parallel Example: User Story 2

```bash
# Launch all variable definitions for User Story 2 together:
Task: "Define alb_name variable in variables.tf"
Task: "Define enable_deletion_protection variable in variables.tf"
Task: "Define health_check_path variable in variables.tf"
Task: "Define health_check_interval variable in variables.tf"
Task: "Define health_check_timeout variable in variables.tf"
Task: "Define healthy_threshold variable in variables.tf"
Task: "Define unhealthy_threshold variable in variables.tf"
Task: "Define deregistration_delay variable in variables.tf"

# Launch all output definitions for User Story 2 together:
Task: "Add ALB outputs to outputs.tf: alb_arn, alb_dns_name, alb_zone_id, target_group_arn"
Task: "Remove instance_public_ip output from outputs.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T012)
2. Complete Phase 2: Foundational (T013-T033) - CRITICAL networking foundation
3. Complete Phase 3: User Story 1 (T034-T051) - Basic nginx on EC2
4. **STOP and VALIDATE**: Test US1 independently - access nginx via instance public IP
5. Decide: Deploy US1 as MVP or continue to US2/US3

**MVP Scope**: VPC + EC2 + nginx = $15-20/month

### Incremental Delivery

1. Complete Setup + Foundational → Network foundation ready
2. Add User Story 1 → Test independently → Basic web server working (MVP!)
3. Add User Story 2 → Test independently → Load balanced, highly available
4. Add User Story 3 → Test independently → Auto-scaling production-ready
5. Each story adds value without breaking previous functionality

### Sequential Execution (Recommended)

Due to US3's dependency on US2's ALB target group:

1. Phase 1: Setup (T001-T012)
2. Phase 2: Foundational (T013-T033)
3. Phase 3: User Story 1 (T034-T051)
4. Phase 4: User Story 2 (T052-T079)
5. Phase 5: User Story 3 (T080-T102)
6. Phase 6: Polish (T103-T130)

### Validation Checkpoints

- **After Setup**: terraform init succeeds, all files created
- **After Foundational**: terraform validate passes, VPC module configured
- **After US1**: nginx accessible via EC2 public IP
- **After US2**: nginx accessible via ALB DNS, health checks passing, multi-AZ deployment
- **After US3**: ASG maintaining desired capacity, scaling policies active
- **After Polish**: All checks pass, ephemeral workspace deployment successful

---

## Notes

- [P] tasks = different files, no dependencies - can run in parallel
- [Story] label maps task to specific user story for traceability and FR compliance
- Each user story should be independently completable and testable
- All tasks reference specific FR-### requirements from spec.md
- Terraform formatting (terraform fmt) run after each implementation phase
- Commit after each user story phase completion
- Stop at any checkpoint to validate independently
- US3 depends on US2's ALB target group - cannot be fully parallelized
- Constitution compliance verified in Phase 6 (module sources, security, IMDSv2, encryption)
- Ephemeral workspace testing (T116-T129) validates complete infrastructure before promotion

**Total Tasks**: 130
**Parallelizable Tasks**: 45 (marked with [P])
**User Story 1 Tasks**: 18 (T034-T051)
**User Story 2 Tasks**: 28 (T052-T079)
**User Story 3 Tasks**: 23 (T080-T102)
**MVP Scope**: Phases 1-3 (T001-T051) = 51 tasks
