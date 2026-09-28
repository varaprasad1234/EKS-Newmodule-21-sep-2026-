#Find Grafana's ACTUAL current password
kubectl get secret -n observability prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

terraform output -raw grafana_password
echo ""
terraform output -raw langfuse_password
echo ""
nslookup grafana.891376962394.realhandsonlabs.net
nslookup langfuse.891376962394.realhandsonlabs.net

