# Cost-Optimized EKS Platform

A static Kubernetes node group runs 24/7 whether anything needs it or not
this project replaces that with capacity that only exists while it's
earning its keep.

## The point of this project

CloudWatch data below shows a static 3-node group idling at 3–5% CPU,
paid for around the clock regardless of demand. Karpenter fixes exactly
that: it watches for pods that can't be scheduled, launches the cheapest
capacity that fits (Spot-first), and terminates it the moment it's no
longer needed no guessing, no static sizing, no idle spend.

That elasticity is proven live in this repo, a pending pod
triggers a real Spot node launch (screenshots below), and deleting the
workload scales it back down automatically once Karpenter's consolidation
window passes.

Everything else here the single-NAT toggle, the S3 lifecycle policy, the
gated Jenkins pipeline is the same underlying discipline applied
elsewhere: know what a resource costs, and only pay for it when it's
actually earning its keep.

## Architecture

VPC → EKS cluster (a small static node group + Karpenter-managed Spot
capacity) → Jenkins (CI/CD, `terraform apply` gated behind manual approval)
→ S3 (Terraform state + a lifecycle-managed log bucket).

Full diagram and every provisioning step: see [`DEPLOYMENT.md`](./DEPLOYMENT.md).

## Cost optimizations, and the tradeoff behind each one

| Optimization                                                      | Saving                                                                    | Tradeoff accepted                                                                                                                                   |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single shared NAT Gateway (not one per AZ)                        | ~50% off NAT cost (~$73→$37/mo)                                           | Both AZs lose egress together if that AZ has an outage acceptable for a non-production workload                                                     |
| Karpenter + Spot for stateless workloads                          | Nodes sized to real demand, not a static guess                            | Spot capacity can be reclaimed with 2 min notice mitigated with a PDB and graceful drain via the SQS interruption queue                             |
| S3 lifecycle: Standard → IA (30d) → Glacier (90d) → delete (365d) | Storage cost drops in stages as data ages                                 | Objects touched early pay Standard-IA's minimum-duration fee the 30-day staging exists specifically to avoid worse Glacier early-deletion penalties |
| Right-sizing from real CloudWatch data                            | Static node group sized to observed ~3–5% CPU utilization, not assumption | Requires the cluster to actually run for a few days before the data is trustworthy                                                                  |

Every decision above including the ones that didn't make this table, and
the real bugs hit implementing them is logged in
[`design-tradeoffs.md`](./design-tradeoffs.md).

## Stack

Terraform · EKS · Karpenter · Jenkins · AWS Cost Explorer · CloudWatch · S3
Lifecycle Policies

## Repo layout

```
bootstrap/          one-time Terraform state backend
environments/dev/   root module  wires every module together
modules/
  vpc/              networking, single-NAT toggle
  eks/              cluster + static node group
  jenkins/          CI/CD, full-pipeline IAM role
  karpenter/        Spot-first autoscaling, interruption handling
  workloads/        sample stateless app for real utilization data
  s3-lifecycle/      log bucket with staged storage-class transitions
Jenkinsfile
design-tradeoffs.md  every real decision made, and why
DEPLOYMENT.md         step-by-step reproduction guide
```

## Documentation

Full setup guide, architecture decisions, and redeployment walkthrough:

[Cost Optimized EKS Platform](https://polarized-boater-990.notion.site/Cost-Optimized-EKS-Platform-3e9604d0a68980b3ab4dc96f1adb73ab)
