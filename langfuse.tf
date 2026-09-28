# =============================================================
# Langfuse v2 - LLM Observability (Postgres-only, lightweight)
#   - chart 0.8.0 = latest v2 (app version 2)
#   - Connects to RDS PostgreSQL (no ClickHouse/Redis/S3 needed)
#   - Exposed at langfuse.<lab_domain>
# =============================================================

resource "kubernetes_namespace" "langfuse" {
  metadata {
    name = "langfuse"
  }
}

locals {
  langfuse_hostname = "${var.langfuse_subdomain}.${local.lab_domain}"
}

resource "helm_release" "langfuse" {
  name       = "langfuse"
  repository = "https://langfuse.github.io/langfuse-k8s"
  chart      = "langfuse"
  namespace  = kubernetes_namespace.langfuse.metadata[0].name
  version    = "0.8.0" # ◀ Latest Langfuse v2 (Postgres-only)

  timeout = 600
  wait    = false

  # ── Use external RDS Postgres, disable bundled ──
  set {
    name  = "postgresql.deploy"
    value = "false"
  }

  set {
    name  = "postgresql.host"
    value = aws_db_instance.langfuse.address
  }

  set {
    name  = "postgresql.auth.username"
    value = var.postgres_username
  }

  set_sensitive {
    name  = "postgresql.auth.password"
    value = var.postgres_password
  }

  set {
    name  = "postgresql.auth.database"
    value = "langfuse"
  }

  # ── Langfuse app config ──
  set {
    name  = "langfuse.nextauth.url"
    value = "https://${local.langfuse_hostname}"
  }

  set_sensitive {
    name  = "langfuse.nextauth.secret"
    value = "changeme-nextauth-secret-min-32-chars-1234567890"
  }

  set_sensitive {
    name  = "langfuse.salt"
    value = "changeme-salt-value-min-16-chars-here"
  }

  depends_on = [aws_db_instance.langfuse]
}

