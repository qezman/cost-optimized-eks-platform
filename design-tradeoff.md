# Design & Tradeoff Log

Every deliberate decision made on this project, in the order made. Format:
**what** was chosen, **why**, and **what was given up** to get it.

---

### 1. Dedicated IAM deployer user, broad service-level permissions (not `AdministratorAccess`, not hand-tuned least-privilege)
- **Chosen:** `cost-optimization-deployer` IAM user with a custom policy granting broad access on the specific services this project touches (EC2, EKS, S3, SQS, EventBridge, CloudWatch), but IAM actions scoped tightly to only the roles/instance-profiles Terraform actually creates.
- **Why:** Terraform's job is to create/modify infrastructure across many services - restricting it service-by-service to exact API calls would mean constant policy-debugging with no real security benefit for a single-operator project. IAM itself was scoped tightly because unrestricted `iam:*` is the one permission that can escalate to full account control.
- **Tradeoff accepted:** Not "least privilege" in the strict sense for EC2/EKS/S3 - deliberately traded for velocity, appropriate for a single-developer project. Would not be acceptable as-is in a multi-team production account.

### 2. Single shared NAT Gateway instead of one per Availability Zone
- **Chosen:** `single_nat_gateway = true` (default) - one NAT Gateway/EIP shared by both private subnets, toggle-able back to one-per-AZ via variable.
- **Why:** NAT Gateway costs $0.045/hr + $0.045/GB processed, plus $0.005/hr per attached EIP (public IPv4 charge, in effect since Feb 2024). Two NAT Gateways run ~$73–80/month before any real traffic; one drops that to ~$37/month - roughly 50% savings on this line item alone.
- **Tradeoff accepted:** If the single NAT Gateway's AZ has an outage, **both** AZs lose internet egress simultaneously, not just one. Project C (the base cluster this reuses) used one-per-AZ specifically to avoid this. Judged acceptable here because this is a portfolio/learning project, not literal production traffic - would reconsider for a real production workload with an SLA.

---

<!-- Add new entries below this line, oldest to newest, same 3-line format. -->