resource "kubernetes_namespace" "kong" {
  metadata {
    name = "kong"
  }
}

resource "helm_release" "kong" {
  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.kong.metadata[0].name
  version    = "2.41.1"

  # Enable Kong Ingress Controller (KIC)
  set {
    name  = "ingressController.enabled"
    value = "true"
  }

  # Kong proxy as ClusterIP; ALB fronts it via the Ingress we manage separately
  set {
    name  = "proxy.type"
    value = "ClusterIP"
  }

  # Disable the chart's built-in ingress — managed in kong-ingress.tf instead
  set {
    name  = "proxy.ingress.enabled"
    value = "false"
  }

  # Load bundled plugins (auth, rate limiting, etc.)
  set {
    name  = "env.plugins"
    value = "bundled"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    kubernetes_storage_class.gp3
  ]
}

