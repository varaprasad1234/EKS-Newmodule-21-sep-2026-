Understanding the data flow
┌──────────────────────────────────────────────────┐
│  GRAFANA (the "viewer" - dashboards & queries)    │
│  Connects to datasources to READ data:            │
└────┬─────────────┬──────────────┬─────────────────┘
     ▼             ▼              ▼
┌─────────┐  ┌──────────┐  ┌──────────┐
│Prometheus│  │  Loki    │  │  Tempo   │
│(metrics) │  │  (logs)  │  │ (traces) │
└─────────┘  └──────────┘  └──────────┘
     ▲             ▲              ▲
     │             │              │  data flows IN
┌────┴─────────────┴──────────────┴─────┐
│  OTel Collector (receives & routes)   │
│  Apps/pods send telemetry here        │
└───────────────────────────────────────┘
Grafana = the dashboard UI. It READS from Prometheus/Loki/Tempo.
Check what's already configured in Grafana
In Grafana UI:
Go to ⚙️ (left menu) → Connections → Data sources
See what's listed
Likely status:
✅ Prometheus — auto-configured by kube-prometheus-stack
❓ Loki — may or may not be added
❓ Tempo — may or may not be added
If Loki/Tempo are missing — add them (easy!)
In Grafana → Connections → Data sources → Add data source:
Loki:
Type: Loki
URL: http://loki-gateway.observability.svc.cluster.local (or http://loki.observability.svc.cluster.local:3100)
Tempo:
Type: Tempo
URL: http://tempo.observability.svc.cluster.local:3100
Prometheus (if missing):
URL: http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090
These use internal ClusterIP DNS — Grafana talks to them inside the cluster (no external exposure needed). 🔒
Best practice: configure datasources via Terraform/Helm (not clicking)
For reproducibility, add datasources to your observability.tf Grafana Helm values instead of clicking. Want me to give you that config? It makes datasources "code" so they survive re-deploys.
❓ Q3: OTel Collector — do I configure it?
What OTel Collector does: It's the central receiver for telemetry. Apps send traces/metrics/logs to it, and it routes them to Tempo (traces), Prometheus (metrics), Loki (logs).
Do you need to configure it in Grafana? No — OTel Collector is NOT a Grafana datasource. It's a pipeline component that feeds the datasources.
When you configure OTel: When you have an application that emits telemetry. You point your app to:
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317
Then OTel routes it to Tempo/Prometheus/Loki, and you view it in Grafana.
Right now you have no app sending telemetry to OTel — so it's idle, waiting. That's fine.
📊 Understanding your running services (the full picture)
Service	Role	Type
kong	API Gateway	Entry/routing
httpbin	Demo API	Test app
aws-load-balancer-controller	Manages ALBs	Infra
external-dns	Auto DNS records	Infra
ebs-csi	Attaches EBS volumes for PVCs	Storage
coredns	Internal DNS	Infra
prometheus	Metrics DB	Observability
grafana	Dashboards UI	Observability
loki	Logs DB	Observability
tempo	Traces DB	Observability
otel-collector	Telemetry router	Observability
alertmanager	Alerting	Observability
node-exporter	Node metrics	Observability
kube-state-metrics	K8s object metrics	Observability
langfuse	LLM observability	GenAI

