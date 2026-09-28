# =============================================================
# Observability Namespace
# =============================================================
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

# =============================================================
# Prometheus (metrics) + Grafana (dashboards)
#   Both come bundled in the kube-prometheus-stack chart
# =============================================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "62.3.0"

  # Enable Grafana (bundled in this chart)
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  # ▼▼▼ Grafana admin password (set on FIRST install only) ▼▼▼
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # ▼▼▼ Grafana served at subdomain ROOT (not subpath) ▼▼▼
  set {
    name  = "grafana.grafana\\.ini.server.root_url"
    value = "https://${local.grafana_hostname}"
  }

  set {
    name  = "grafana.grafana\\.ini.server.serve_from_sub_path"
    value = "false"
  }
  # ▲▲▲ Grafana root_url ▲▲▲

  # ▼▼▼ Auto-provision Loki + Tempo datasources (with tenant header) ▼▼▼
  # Loki has auth_enabled=true, so it REQUIRES X-Scope-OrgID header
  values = [
    yamlencode({
      grafana = {
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            access    = "proxy"
            url       = "http://loki-gateway.observability.svc.cluster.local"
            isDefault = false
            jsonData = {
              httpHeaderName1 = "X-Scope-OrgID"
            }
            secureJsonData = {
              httpHeaderValue1 = "1"
            }
          },
          {
            name      = "Tempo"
            type      = "tempo"
            access    = "proxy"
            url       = "http://tempo.observability.svc.cluster.local:3100"
            isDefault = false
            jsonData = {
              httpHeaderName1  = "X-Scope-OrgID"
              httpHeaderValue1 = "1"
            }
          }
        ]
      }
    })
  ]
  # ▲▲▲ Datasources ▲▲▲

  # Persistent storage via gp3
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp3"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "20Gi"
  }

  depends_on = [kubernetes_storage_class.gp3]
}

# =============================================================
# Loki (logs) - SingleBinary mode, filesystem storage (lab-friendly)
# =============================================================
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "6.10.0"

  set {
    name  = "deploymentMode"
    value = "SingleBinary"
  }

  set {
    name  = "singleBinary.replicas"
    value = "1"
  }

  set {
    name  = "loki.storage.type"
    value = "filesystem"
  }

  set {
    name  = "loki.commonConfig.replication_factor"
    value = "1"
  }

  # Provides a ready-made schema for testing (no S3 needed)
  set {
    name  = "loki.useTestSchema"
    value = "true"
  }

  set {
    name  = "read.replicas"
    value = "0"
  }
  set {
    name  = "write.replicas"
    value = "0"
  }
  set {
    name  = "backend.replicas"
    value = "0"
  }
  set {
    name  = "chunksCache.enabled"
    value = "false"
  }
  set {
    name  = "resultsCache.enabled"
    value = "false"
  }
  set {
    name  = "test.enabled"
    value = "false"
  }
  set {
    name  = "lokiCanary.enabled"
    value = "false"
  }

  depends_on = [kubernetes_storage_class.gp3]
}

# =============================================================
# Tempo (traces)
# =============================================================
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "1.10.3"

  depends_on = [kubernetes_storage_class.gp3]
}

# =============================================================
# OpenTelemetry Collector
#   Receives telemetry, exports to Prometheus/Loki/Tempo
# =============================================================
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "0.102.1"

  set {
    name  = "mode"
    value = "deployment"
  }

  # Collector pipeline config from values file
  values = [file("${path.module}/otel-values.yaml")]

  depends_on = [
    helm_release.prometheus,
    helm_release.loki,
    helm_release.tempo
  ]
}

