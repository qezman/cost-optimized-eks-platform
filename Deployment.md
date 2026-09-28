# Deployment Guide - Reproducing This Project From Scratch

This walks through standing up the full platform in the same order it was
actually built and applied. Follow it in order - later modules assume
earlier ones already exist.

## Prerequisites

- AWS CLI configured with credentials for the account you're deploying into
- Terraform >= 1.6.0
- kubectl
- git

## Step 0 - IAM deployer user

Create a dedicated IAM user (not your personal/root credentials) scoped to
exactly what this project needs. See `cost-optimization-deployer-policy.json`
for the exact policy - it's broad on EC2/EKS/S3 (Terraform needs to create
these freely) but deliberately narrow on IAM itself (no `iam:*`).

Attach the policy, generate an access key, and export it as a named AWS CLI
profile:

```bash
export AWS_PROFILE=cost-optimization-deployer
```

## Step 1 - Bootstrap the Terraform state backend

```bash
cd bootstrap
# Edit variables.tf: set state_bucket_name to something globally unique
terraform init
terraform plan   # expect exactly 4 resources
terraform apply
```

This creates the S3 bucket that every other module's state lives in. It
uses local state itself - a deliberate, one-time exception.

## Step 2 - Point the root module at that backend

```bash
cd ../environments/dev
# Edit backend.tf: bucket must match state_bucket_name from Step 1 exactly
```

## Step 3 - VPC and EKS cluster (first apply, targeted)

The `environments/dev` root module wires every service together, but the
Kubernetes/Helm/kubectl providers can't authenticate until the EKS cluster
actually exists - so the very first apply has to be scoped:

```bash
terraform init
terraform apply -target=module.vpc -target=module.eks
```

Verify before continuing:

```bash
aws eks update-kubeconfig --name cost-optimization-dev --region us-east-1
kubectl get nodes   # expect 3 nodes, Ready
```

## Step 4 - Everything else

```bash
terraform apply
```

This applies `workloads`, `jenkins`, `karpenter`, and `s3-lifecycle` in one
pass - the cluster now exists, so the Kubernetes-facing providers can
authenticate.

Verify:

```bash
kubectl get pods -n sample-workloads      # 3 pods, Running
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter   # 2 pods, Running
```

## Step 5 - Prove Karpenter actually works

Don't just trust the apply - force a real provisioning event:

```bash
kubectl create deployment karpenter-test --image=public.ecr.aws/nginx/nginx:stable --replicas=1
kubectl set resources deployment karpenter-test --requests=cpu=50m,memory=64Mi
kubectl patch deployment karpenter-test -p '{"spec":{"template":{"spec":{"nodeSelector":{"karpenter.sh/nodepool":"default"}}}}}'

kubectl get nodeclaims   # a NodeClaim should appear, then go Ready
kubectl get nodes        # a 4th node should join

kubectl delete deployment karpenter-test   # clean up once confirmed
```

## Step 6 - Jenkins pipeline

1. `terraform output jenkins_public_ip`
2. SSH in: `ssh -i <private-key> ubuntu@<ip>`
3. `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
4. Open `http://<ip>:8080`, complete setup with that password
5. **Manage Jenkins → Credentials** → add a **Secret file** credential, ID
   `tf-tfvars`, containing your real `terraform.tfvars`
6. **New Item** → Pipeline → **Pipeline script from SCM** → point at this
   repo, branch `main`, script path `Jenkinsfile`
7. **Build Now** - the pipeline runs Lint → Plan → pauses for manual
   approval → Apply → a post-apply health check

## Ongoing gotcha worth knowing before you hit it

If your public IP changes between sessions (common on residential ISPs),
`kubectl`/`helm`/`terraform` will time out trying to reach the cluster's API
- because the EKS endpoint's allow-list still has your *old* IP, and you
need to already be allowed through to apply the fix. This repo resolves it
permanently via a live `http` data source (`environments/dev/ip.tf`) that
detects your current IP at plan time - no manual `.tfvars` editing needed,
ever, after this is in place.

## Step 7 - Tear down

```bash
cd environments/dev
terraform plan
terraform destroy

```

Then, separately, `bootstrap`'s state bucket if you want nothing left at all
(optional - it costs pennies to leave, and destroying it means losing
Terraform state history).