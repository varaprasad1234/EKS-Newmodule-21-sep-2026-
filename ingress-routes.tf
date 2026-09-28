# =============================================================
# Ingress Routes - Subdomain-based via shared ALB + ExternalDNS
#   - langfuse.<lab_domain> -> Langfuse (port 3000)
#   - grafana.<lab_domain>  -> Grafana  (port 80)
# =============================================================

locals {
  grafana_hostname = "${var.grafana_subdomain}.${local.lab_domain}"
}

# ── Langfuse Ingress ──
resource "kubernetes_ingress_v1" "langfuse" {
  wait_for_load_balancer = false

  metadata {
    name      = "langfuse"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/group.name"      = "shared-alb"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = local.certificate_arn
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "external-dns.alpha.kubernetes.io/hostname" = local.langfuse_hostname
    }
  }

  spec {
    rule {
      host = local.langfuse_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "langfuse"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.langfuse]
}

# ── Grafana Ingress ──
resource "kubernetes_ingress_v1" "grafana" {
  wait_for_load_balancer = false

  metadata {
    name      = "grafana"
    namespace = "observability"
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/group.name"      = "shared-alb"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = local.certificate_arn
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "external-dns.alpha.kubernetes.io/hostname" = local.grafana_hostname
    }
  }

  spec {
    rule {
      host = local.grafana_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

