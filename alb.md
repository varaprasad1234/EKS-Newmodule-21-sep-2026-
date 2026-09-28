aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(DNSName, 'k8s-kong-kongprox-3da0bd1df7')].LoadBalancerArn" \
    --output text) \
  --query "Listeners[*].{Protocol:Protocol,Port:Port}" \
  --output table
#####
The full picture — how they connect 🔗
Here's the chain, from name to reality:
┌─────────────────────────────────────────────────────────────┐
│  Ingress "kong-proxy"  (the ADDRESS SIGN / routing rule)      │
│  → tells ALB Controller: "build an ALB, send traffic to..."   │
└────────────────────────────┬────────────────────────────────┘
                             │ points to
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Service "kong-kong-proxy"  (Kong's internal PHONE NUMBER)    │
│  → a stable address inside the cluster                        │
└────────────────────────────┬────────────────────────────────┘
                             │ routes to
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Pod "kong-kong-xxxxx"  (the ACTUAL KONG software running)    │
│  → this is the real Kong Gateway processing requests          │
└─────────────────────────────────────────────────────────────┘
In plain words:
Traffic hits the ALB (built from the Ingress).
ALB sends it to the kong-kong-proxy Service.
The Service forwards it to the Kong Pod.
Kong processes it (auth, routing, rate limiting).
Part 4: How to inspect Kong — command cheat sheet 🛠️
See everything in the kong namespace at once
kubectl get all -n kong
This shows pods, services, deployments — the whole picture.
Look at the Kong pod in detail
kubectl get pods -n kong
# then describe it (replace with your actual pod name):
kubectl describe pod kong-kong-xxxxxxxxxx-xxxxx -n kong
See Kong's logs (what it's doing)
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=50
You'll see log lines for the requests you've been making! Look for your request_ids.
See the Kong deployment
kubectl get deployment -n kong
Confirm which container images Kong is running
kubectl get pods -n kong -o jsonpath='{.items[*].spec.containers[*].image}' ; echo
Part 5: Understanding "Ingress" vs "Kong" — the key insight 💡
You actually have TWO layers of routing here, which is worth understanding:
Layer	What	Role
Layer 1: ALB Ingress (class: alb)	The kong-proxy Ingress → AWS ALB	Gets traffic from the internet into the cluster, terminates TLS
Layer 2: Kong (class: kong)	Kong Gateway pods + KIC	Does the smart API gateway stuff: auth, rate limiting, routing to your apps
So the flow is:
Internet → ALB (Layer 1, from the alb Ingress) → Kong (Layer 2) → your apps
When you later deploy apps, you'll create Kong Ingresses (class: kong) that tell Kong how to route to each app. Those are different from the single alb Ingress that gets you into the cluster.
Quick commands to run right now
Try these to see Kong for yourself:
# 1. See Kong pods (the real Kong)
kubectl get pods -n kong

# 2. See Kong's service (what the Ingress points to)
kubectl get svc -n kong

# 3. See everything together
kubectl get all -n kong

# 4. Watch Kong's logs while you curl it
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=20 -f
Then in another terminal, run your curl and watch the logs light up:
curl -k https://app.381491852311.realhandsonlabs.net
