# Design & Tradeoff Log

Every deliberate decision made on this project, in the order made. Format:
**what** was chosen, **why**, and **what was given up** to get it.

---

### 1. Dedicated IAM deployer user, broad service-level permissions (not `AdministratorAccess`, not hand-tuned least-privilege)

- **Chosen:** `cost-optimization-deployer` IAM user with a custom policy granting broad access on the specific services this project touches (EC2, EKS, S3, SQS, EventBridge, CloudWatch), but IAM actions scoped tightly to only the roles/instance-profiles Terraform actually creates.
- **Why:** Terraform's job is to create/modify infrastructure across many services - restricting it service-by-service to exact API calls would mean constant policy-debugging with no real security benefit for a single-operator project. IAM itself was scoped tightly because unrestricted `iam:`\* is the one permission that can escalate to full account control.
- **Tradeoff accepted:** Not "least privilege" in the strict sense for EC2/EKS/S3 - deliberately traded for velocity, appropriate for a single-developer project. Would not be acceptable as-is in a multi-team production account.

### 2. Single shared NAT Gateway instead of one per Availability Zone

- **Chosen:** `single_nat_gateway = true` (default) - one NAT Gateway/EIP shared by both private subnets, toggle-able back to one-per-AZ via variable.
- **Why:** NAT Gateway costs $0.045/hr + $0.045/GB processed, plus $0.005/hr per attached EIP (public IPv4 charge, in effect since Feb 2024). Two NAT Gateways run ~$73–80/month before any real traffic; one drops that to ~$37/month - roughly 50% savings on this line item alone.
- **Tradeoff accepted:** If the single NAT Gateway's AZ has an outage, **both** AZs lose internet egress simultaneously, not just one. Project C (the base cluster this reuses) used one-per-AZ specifically to avoid this. Judged acceptable here because this is a portfolio/learning project, not literal production traffic - would reconsider for a real production workload with an SLA.

---

### 3. Continuous 24h+ uptime for the baseline window

- Chosen: leave dev environment running continuously (not destroyed between sessions) for a sustained window once all modules are applied.
- Why: Cost Explorer/CloudWatch need continuous accumulated usage to produce a legitimate "before" baseline - destroy-between-sessions (previous entry) directly conflicts with this need.
- Tradeoff accepted: real AWS spend accrues the whole time, unattended. Mitigated by finishing all modules first so the clock only starts once the full intended shape is running.

### 4. Hardcoded ARN naming coupling between Jenkins's IAM policy and Karpenter's resources

- Chosen: Jenkins's terraform_deployer policy references Karpenter's SQS queue and EventBridge rule ARNs as hardcoded strings (constructed from project/environment naming convention), since Jenkins was built before Karpenter existed and Terraform modules can't reference resources across unrelated modules without real coupling.
- Why: keeps modules independently plannable - Jenkins doesn't need Karpenter to exist to be applied, avoiding a cross-module dependency that would break module isolation.
- Tradeoff accepted: fragile by construction - resource names in modules/karpenter must exactly match the strings hardcoded in modules/jenkins, with no compiler/validator enforcing this. Caught in practice: first draft of the SQS queue/EventBridge rule used different names ("spot-interruption" vs the expected "karpenter-interruption", plus an extra "\_rule" suffix) - would have silently left Jenkins unable to manage either resource if not manually cross-checked against the hardcoded ARNs.

### 5. Controller runtime permissions are separate from provisioning permissions

- Chosen: Karpenter's controller IAM role needed its own SQS permissions, distinct from the deployer's permission to create the queue via Terraform.
- Why: an identity that can create a resource isn't automatically allowed to use it at runtime - two different permission boundaries.
- Lesson: caused a misleading "NonExistentQueue" error (AWS hides "access denied" as "doesn't exist" for SQS) - cost real debugging time before the actual cause (missing runtime grant) was found.

### 6. ec2:CreateTags is a separate permission from resource creation

- Chosen: added a dedicated IAM statement for ec2:CreateTags.
- Why: AWS treats "create a resource" and "tag it at creation" as two distinct permissions - granting CreateLaunchTemplate/RunInstances doesn't include the right to tag what you just created.
- Tradeoff: used Resource "\*" for time; AWS's reference policy scopes this tighter with a CreateAction condition - known simplification, not fixed.

### 7. aws_ec2_tag conflicts with a resource's own `tags` argument

- Chosen: used lifecycle.ignore_changes on the specific tag key in the vpc module's subnet resource.
- Why: aws_ec2_tag (karpenter module) and aws_subnet's own tags block (vpc module) both tried to own the same tag, each apply undoing the other's change.
- Tradeoff: modules stay independent, but requires remembering to ignore that one key wherever it's set elsewhere.

### 8. Karpenter v1beta1 → v1 API migration

- Chosen: used karpenter.k8s.aws/v1 and karpenter.sh/v1 (chart 1.0.1), not v1beta1.
- Why: v1beta1 deprecated at Karpenter 1.0; required real schema changes - amiSelectorTerms became mandatory, consolidateAfter became mandatory, consolidationPolicy value renamed, nodeClassRef needs an explicit group field.
- Lesson: version-specific API docs matter more than general Karpenter knowledge; each field gap surfaced as a separate apply-time error, not a single upfront warning.

### 9. Spot Instances require a one-time account-level service-linked role

- Chosen: let the deployer create AWSServiceRoleForEC2Spot directly (once), rather than relying solely on the controller's own iam:CreateServiceLinkedRole grant.
- Why: first Spot launch in an account needs this role to exist; multiple IAM principals (deployer, controller role) were each missing a piece of the permission chain.
- Lesson: a single Spot launch touches three separate IAM identities' permissions (deployer, Karpenter controller, EC2 service-linked role) - real complexity worth naming, not a sign of over-engineering.
