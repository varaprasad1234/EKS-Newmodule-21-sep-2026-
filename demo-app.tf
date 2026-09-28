# =============================================================
# Demo API (httpbin) - routed THROUGH Kong to test the gateway
#   Access: https://app.<lab_domain>/api
# =============================================================

resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_deployment" "httpbin" {
  metadata {
    name      = "httpbin"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "httpbin" }
    }
    template {
      metadata {
        labels = { app = "httpbin" }
      }
      spec {
        container {
          name  = "httpbin"
          image = "kennethreitz/httpbin"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "httpbin" {
  metadata {
    name      = "httpbin"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  spec {
    selector = { app = "httpbin" }
    port {
      port        = 80
      target_port = 80
    }
  }
}

# Route through KONG (not ALB directly) - this tests Kong!
resource "kubernetes_ingress_v1" "httpbin" {
  metadata {
    name      = "httpbin"
    namespace = kubernetes_namespace.demo.metadata[0].name
    annotations = {
      "konghq.com/strip-path"                       = "true"
      "external-dns.alpha.kubernetes.io/controller" = "none"  # ◀ ADDED: ExternalDNS ignores this Kong ingress
    }
  }
  spec {
    ingress_class_name = "kong"
    rule {
      host = local.app_hostname
      http {
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "httpbin"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.httpbin]
}

