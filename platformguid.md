📘 GenAI Platform on EKS — Complete Guide & Runbook
Table of Contents
Architecture Overview
What You Built (Component Guide)
Access & Credentials
Troubleshooting Runbook
Common Commands Cheat Sheet
Teardown & Cleanup
1. Architecture Overview
Internet
   │
   ▼
Route53 DNS  ◄──── ExternalDNS (auto-creates records)
   │  app.<lab>.net, grafana.<lab>.net, langfuse.<lab>.net
   ▼
┌─────────────────────────────────────────────┐
│  Application Load Balancers (ALB)            │
│  - Kong ALB      → app.<lab>.net             │
│  - Shared ALB    → grafana./langfuse.<lab>   │
│  - Wildcard TLS cert (ACM) on all            │
└──────────┬─────────────────────┬─────────────┘
           ▼                     ▼
┌──────────────────┐   ┌────────────────────────┐
│  Kong Gateway    │   │  Direct ALB routes      │
│  (DB-less)       │   │  - Grafana (root)       │
│  /api → httpbin  │   │  - Langfuse (root)      │
└──────────────────┘   └──────────┬─────────────┘
                                   ▼
                       ┌────────────────────────┐
                       │  RDS PostgreSQL         │
                       │  (Langfuse database)    │
                       └────────────────────────┘

Observability: Prometheus + Grafana + Loki + Tempo + OTel
LLM Observability: Langfuse (traces, prompts, scores)
2. What You Built (Component Guide)
Component	Purpose	Namespace	Access
EKS Cluster	Kubernetes control plane + nodes	-	kubectl
VPC	Network (3 AZs, public+private subnets)	-	-
Kong (DB-less)	API Gateway (routing, plugins)	kong	app..net
httpbin	Demo API to test Kong	demo	app..net/api
Grafana	Metrics dashboards	observability	grafana..net
Prometheus	Metrics collection	observability	(internal)
Loki	Log aggregation	observability	(internal)
Tempo	Distributed tracing	observability	(internal)
Langfuse v2	LLM observability	langfuse	langfuse..net
RDS PostgreSQL	Langfuse database	(AWS)	private only
ExternalDNS	Auto DNS records	kube-system	(automatic)
ALB Controller	Manages ALBs	kube-system	(automatic)
Key Design Decisions
Kong DB-less: configured via Kubernetes YAML/CRDs (not GUI). K8s-native, GitOps-friendly.
Langfuse v2 (chart 0.8.0): Postgres-only. v3 (chart 0.9.0+) needs ClickHouse+Redis+S3 (too heavy).
Subdomains not subpaths: avoids redirect loops. Each app at clean root domain.
RDS not pod-Postgres: managed, persistent database for Langfuse.
IRSA: least-privilege IAM for ExternalDNS/ALB controller (no hardcoded keys).
exec provider auth: fresh EKS token every call (no expiry issues).
3. Access & Credentials
Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name kong-platform
Get all URLs
terraform output
Get passwords
terraform output -raw grafana_password
terraform output -raw langfuse_password
Service URLs
Service	URL	Login
Grafana	https://grafana..net	admin / (grafana_password)
Langfuse	https://langfuse..net	admin@lab.local / (langfuse_password)
Demo API	https://app..net/api/get	(public)
4. 🔧 Troubleshooting Runbook
Problem: ERR_TOO_MANY_REDIRECTS (redirect loop)
Cause: Grafana's serve_from_sub_path / root_url mismatch with its actual location.
Fix:
If Grafana is at a subdomain root (grafana..net): set serve_from_sub_path = false, root_url = https://grafana.<lab>.net
If Grafana is at a subpath (app..net/grafana): set serve_from_sub_path = true, and Kong strip-path = false
Golden rule: serve_from_sub_path and the actual serving path MUST agree.
Steps:
# 1. Fix observability.tf settings (above)
terraform apply
# 2. Restart Grafana
kubectl rollout restart deployment prometheus-grafana -n observability
# 3. CLEAR COOKIES / use Incognito (loop caches bad cookies!)
Problem: Unauthorized / cluster unreachable (Terraform)
Cause: Provider auth token stale/expired on fresh cluster.
Fix: Ensure providers-k8s.tf uses exec (not static token):
provider "kubernetes" {
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}
Verify manually:
aws sts get-caller-identity
aws eks update-kubeconfig --region us-east-1 --name kong-platform
kubectl get nodes
Problem: ingress status ... is empty list (Route53 alias)
Cause: ALB not ready when Terraform read its address.
Fix:
Ensure wait_for_load_balancer = true on the Kong ingress
Wait for ALB, then re-run terraform apply
Check:
kubectl get ingress -A   # look for populated ADDRESS
Problem: RDS Cannot find version X.Y
Cause: AWS retired that PostgreSQL minor version.
Fix: Use major version only:
engine_version = "16"    # not "16.4"
Find valid versions:
aws rds describe-db-engine-versions --engine postgres \
  --query "DBEngineVersions[?starts_with(EngineVersion,'16')].EngineVersion" --output table
Problem: Langfuse pod CrashLoopBackOff with ClickHouse/Redis errors
Cause: Deployed Langfuse v3 (needs ClickHouse+Redis+S3).
Fix: Use v2 chart (Postgres-only):
version = "0.8.0"   # Langfuse v2 (app version 2)
Verify version mapping:
helm search repo langfuse/langfuse --versions
# Chart 0.8.0 = APP 2 (v2) ✅ | Chart 0.9.0+ = APP 3/4 (v3) ❌
Cleanup failed release before retry:
helm uninstall langfuse -n langfuse
terraform state rm helm_release.langfuse
Problem: Helm context deadline exceeded
Cause: Pod didn't become ready within timeout.
Fix: In the helm_release, add:
timeout = 600
wait    = false
Then diagnose the actual pod:
kubectl get pods -n <namespace>
kubectl logs -n <namespace> <pod> --tail=80
kubectl describe pod -n <namespace> <pod> | tail -40
Problem: Subdomain doesn't resolve / 404
Diagnosis flow:
# 1. DNS created?
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=30 | grep -i create
dig grafana.<lab>.net +short          # should return ALB IPs

# 2. Ingress has address?
kubectl get ingress -A                # ADDRESS populated?

# 3. Service exists & has endpoints?
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>  # should list pod IPs

# 4. Pod running?
kubectl get pods -n <namespace>
Common fixes:
DNS not propagated → wait 2-5 min
Wrong service name in ingress → check kubectl get svc
Certificate mismatch → verify wildcard cert covers subdomain
Problem: Pod Pending (won't schedule)
Cause: Not enough node resources (memory/CPU).
Diagnose:
kubectl describe pod -n <namespace> <pod> | grep -A5 Events
kubectl top nodes          # check capacity
kubectl get pods -A -o wide | grep Pending
Fix: Add nodes or bigger instances in variables.tf, then terraform apply.
5. Common Commands Cheat Sheet
Cluster
aws eks update-kubeconfig --region us-east-1 --name kong-platform
kubectl get nodes
kubectl top nodes
kubectl get pods -A
Ingress / Routing
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
Logs
kubectl logs -n <namespace> -l app=<label> --tail=50 -f
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=30
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
DNS
dig grafana.<lab>.net +short
nslookup langfuse.<lab>.net
Kong (DB-less inspection)
kubectl get ingress -A                          # your Kong routes
kubectl get kongplugin -A                        # plugins
kubectl port-forward -n kong <pod> 8001:8001     # Admin API
curl http://localhost:8001/routes | jq
RDS
aws rds describe-db-instances \
  --db-instance-identifier kong-platform-langfuse \
  --query 'DBInstances[0].DBInstanceStatus' --output text
Restart a deployment
kubectl rollout restart deployment <name> -n <namespace>
kubectl rollout status deployment <name> -n <namespace>
Terraform
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform output -raw <sensitive_output>
terraform state list
terraform state rm <resource>       # remove from state (careful!)
6. Teardown & Cleanup
⚠️ Order matters (avoid stuck resources)
# 1. Delete ingresses first (removes ALBs + DNS records)
kubectl delete ingress --all -A

# 2. Wait for ALBs to delete (~2 min), verify in AWS console

# 3. Destroy Terraform
terraform destroy
If terraform destroy hangs
# Manually check for orphaned resources:
# - ALBs (EC2 → Load Balancers)
# - Route53 records (ExternalDNS should clean, but verify)
# - RDS (should delete with skip_final_snapshot=true)
Force-clean stuck namespace
kubectl get namespace <ns> -o json | jq '.spec.finalizers = []' | \
  kubectl replace --raw /api/v1/namespaces/<ns>/finalize -f -
📗 Quick Concepts Reference (for understanding)
What is Kong DB-less mode?
Kong runs without a database. All config comes from Kubernetes resources (Ingresses, KongPlugin CRDs). You manage it via kubectl apply YAML, not a GUI. Reproducible, GitOps-friendly.
What is IRSA?
IAM Roles for Service Accounts. Lets a K8s pod assume an AWS IAM role via OIDC — no hardcoded AWS keys. Used by ExternalDNS (Route53 access) and ALB Controller (ELB access).
What is ExternalDNS?
A controller that watches your Ingresses and automatically creates/deletes Route53 DNS records to match. No manual DNS editing.
Why subdomains over subpaths?
Apps like Grafana/Langfuse assume they live at / (root). Serving under /grafana requires special config (serve_from_sub_path) and often causes redirect loops. Subdomains (grafana.lab.net) give each app a clean root — "just works."
Why RDS for Langfuse?
Langfuse needs persistent PostgreSQL. RDS is managed (backups, patching, HA) and offloads the DB from your cluster nodes. Langfuse v2 needs ONLY Postgres.
What is the exec provider auth pattern?
Instead of fetching an EKS token once (which expires during long applies), exec runs aws eks get-token live on every API call — always fresh, never expires.
📙 Your Specific Values (fill in & save)
Cluster:         kong-platform
Region:          us-east-1
Lab Domain:      891376962394.realhandsonlabs.net
VPC:             vpc-05a9cc6e962c6c9bd
RDS Endpoint:    kong-platform-langfuse.cv6io4qiiq58.us-east-1.rds.amazonaws.com

URLs:
  Kong/App:      https://app.891376962394.realhandsonlabs.net
  Demo API:      https://app.891376962394.realhandsonlabs.net/api
  Grafana:       https://grafana.891376962394.realhandsonlabs.net
  Langfuse:      https://langfuse.891376962394.realhandsonlabs.net

Credentials (retrieve via terraform output -raw <name>):
  Grafana:       admin / grafana_password
  Langfuse:      admin@lab.local / langfuse_password
🎯 When You Come Back — Next Steps
Fix the Grafana redirect loop (set serve_from_sub_path = false — details in Troubleshooting section above)
Verify all 3 URLs work in browser
Then explore:
Send LLM traces to Langfuse (the real use case!)
Add Kong plugins (rate-limiting, auth) on /api
Wire Loki/Tempo into Grafana dashboards

