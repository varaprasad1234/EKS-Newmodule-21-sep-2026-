# =============================================================
# App outputs
#
# NOTE: DNS for app.* is now managed by ExternalDNS (via the
#       external-dns hostname annotation on the Kong ingress),
#       NOT by Terraform. This avoids the create-record race
#       condition. The old aws_route53_record.app and
#       aws_elb_hosted_zone_id data source were removed.
# =============================================================

output "app_url" {
  value = var.enable_tls ? "https://${local.app_hostname}" : "http://${local.app_hostname}"
}

output "lab_domain" {
  value = local.lab_domain
}

output "alb_dns_name" {
  value = try(kubernetes_ingress_v1.kong_proxy.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

