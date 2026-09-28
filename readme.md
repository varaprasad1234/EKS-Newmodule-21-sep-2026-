.
├── acm.tf
├── alb-controller.tf
├── alb.md
├── clean.sh
├── demo-app.tf
├── eks.tf
├── eks.tf_org
├── external-dns-irsa.tf
├── external-dns.tf
├── external-dns.tf-org-sep-27
├── grafana-ingress.yaml
├── ingress-routes.tf
├── irsa.tf
├── kong-ingress.tf
├── kong-manager-ingress.yaml
├── kong-url-check.txt
├── kong.tf
├── langfuse.tf
├── loki-values.yaml
├── nohup.out
├── obserability_test.sh
├── obserability.md
├── observability.tf
├── observability.tf_org
├── otel-values.yaml
├── outputs.tf
├── pass.sh
├── platformguid.md
├── providers-k8s.tf
├── rds.tf
├── readme.md
├── route53-alias.tf
├── route53-alias.tf_org
├── storage.tf
├── terraform.tfstate
├── terraform.tfstate.backup
├── variables.tf
├── versions.tf
└── vpc.tf


aws eks update-kubeconfig --region us-east-1 --name kong-platform
grafana psswd
kubectl get secret -n observability prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
Verify Kong is reachable (the real test):
curl -k https://k8s-kong-kongprox-3da0bd1df7-1210600505.us-east-1.elb.amazonaws.com -H "Host: app.381491852311.realhandsonlabs.net"
Key takeaways (worth remembering for future labs)
DNS records aren't instant — always allow a few minutes for propagation after creating them.
Negative caching is real — if you query a name before it exists, your resolver may cache the "doesn't exist" answer. Avoid checking too early, or you'll cache a false negative.
To test DNS immediately (bypass caching), query Route53's nameservers directly:
aws route53 get-hosted-zone --id Z082065524TDULAP5U3EQ \
  --query 'DelegationSet.NameServers' --output text
# then:
nslookup app.381491852311.realhandsonlabs.net <one-of-those-nameservers>
To flush your local DNS cache (if you're impatient):
Mac: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
Linux (systemd): sudo systemd-resolve --flush-caches or sudo resolvectl flush-caches
Your Terraform was never wrong — the record was created correctly all along. It was purely a timing/caching issue on the DNS resolution side.


