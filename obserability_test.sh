echo "=== Loki pods ==="
kubectl get pods -n observability | grep loki

echo "=== Loki backend logs ==="
kubectl logs -n observability loki-0 --tail=20

echo "=== Test gateway /ready ==="
kubectl run loki-t1 --rm -it --restart=Never --image=curlimages/curl -n observability -- \
  curl -s http://loki-gateway.observability.svc.cluster.local/ready

echo "=== Test backend /ready ==="
kubectl run loki-t2 --rm -it --restart=Never --image=curlimages/curl -n observability -- \
  curl -s http://loki.observability.svc.cluster.local:3100/ready

echo "=== Auth mode ==="
kubectl get cm -n observability -l app.kubernetes.io/name=loki -o yaml 2>/dev/null | grep -i auth_enabled

echo "=== Test labels endpoint (what Grafana actually calls) ==="
kubectl run loki-t3 --rm -it --restart=Never --image=curlimages/curl -n observability -- \
  curl -s -H "X-Scope-OrgID: 1" http://loki-gateway.observability.svc.cluster.local/loki/api/v1/labels

