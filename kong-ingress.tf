# =============================================================
# ALB Ingress fronting the Kong proxy
#   - TLS terminated at the ALB using the ACM cert
#   - HTTP -> HTTPS redirect when TLS enabled
# =============================================================
resource "kubernetes_ingress_v1" "kong_proxy" {
  wait_for_load_balancer = true # ◀ MUST be present
  metadata {
    name      = "kong-proxy"
    namespace = kubernetes_namespace.kong.metadata[0].name

    annotations = merge(
      {
        "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
        "alb.ingress.kubernetes.io/target-type" = "ip"
        # Health check against Kong's status endpoint
        "alb.ingress.kubernetes.io/healthcheck-path" = "/"
        "alb.ingress.kubernetes.io/group.name"       = "shared-alb"  # ◀ ADD THIS
        "external-dns.alpha.kubernetes.io/hostname"  = local.app_hostname  # ◀ ADD THIS
      },
      var.enable_tls ? {
        "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
        "alb.ingress.kubernetes.io/certificate-arn" = local.certificate_arn
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
      }
    )
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = local.app_hostname # app.<labid>.realhandsonlabs.net

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kong-kong-proxy" # release "kong" + chart "kong"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kong,
    aws_acm_certificate_validation.this
  ]
}

