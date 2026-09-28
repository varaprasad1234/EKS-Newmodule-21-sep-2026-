output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
# ── Service URLs ──
output "langfuse_url" {
  value = "https://${local.langfuse_hostname}"
}

output "grafana_url" {
  value = "https://${local.grafana_hostname}"
}

output "demo_api_url" {
  description = "Test API through Kong (try /api/get, /api/headers)"
  value       = "https://${local.app_hostname}/api"
}

# ── Langfuse credentials ──
output "langfuse_email" {
  value = var.langfuse_admin_email
}

output "langfuse_password" {
  value     = var.langfuse_admin_password
  sensitive = true
}

# ── Grafana credentials ──
output "grafana_username" {
  value = "admin"
}

output "grafana_password" {
  description = "Retrieve with: terraform output -raw grafana_password"
  value       = var.grafana_admin_password
  sensitive   = true
}

# ── RDS info ──
output "rds_endpoint" {
  value = aws_db_instance.langfuse.address
}

