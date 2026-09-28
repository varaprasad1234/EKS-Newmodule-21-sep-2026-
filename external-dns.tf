resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.0"

  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  # Only manage records in YOUR lab domain
  set {
    name  = "domainFilters[0]"
    value = local.lab_domain
  }

  # sync = create AND delete records to match cluster state
  set {
    name  = "policy"
    value = "sync"
  }

  # Unique owner ID so ExternalDNS only touches its own records
  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  # Attach the IRSA role
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa.iam_role_arn
  }

  # ── Watch ONLY ingress resources (NOT service) ──
  set {
    name  = "sources[0]"
    value = "ingress"
  }

  # ▼▼▼ FIX: only use the hostname ANNOTATION, ignore the host: field ▼▼▼
  # This prevents Kong-class ingresses (which reuse host: app.*) from
  # being treated as DNS sources with their ClusterIP status.
  set {
    name  = "extraArgs[0]"
    value = "--ingress-class=alb"
  }
  set {
    name  = "extraArgs[1]"
    value = "--ignore-ingress-tls-spec"
  }
  # ▲▲▲ FIX ▲▲▲

  depends_on = [module.eks]
}

