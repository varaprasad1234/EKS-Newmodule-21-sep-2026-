# ▼▼▼ NEW: Passwords & Langfuse/RDS config ▼▼▼

variable "grafana_admin_password" {
  description = "Grafana admin password (retrievable via terraform output)"
  type        = string
  default     = "ChangeMe-Grafana-2026!"
  sensitive   = true
}

variable "langfuse_admin_email" {
  description = "Langfuse initial admin email"
  type        = string
  default     = "admin@lab.local"
}

variable "langfuse_admin_password" {
  description = "Langfuse initial admin password"
  type        = string
  default     = "ChangeMe-Langfuse-2026!"
  sensitive   = true
}

variable "postgres_username" {
  description = "PostgreSQL master username for RDS"
  type        = string
  default     = "langfuse"
}

variable "postgres_password" {
  description = "PostgreSQL master password for RDS"
  type        = string
  default     = "ChangeMe-Postgres-2026!"
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class for Langfuse Postgres"
  type        = string
  default     = "db.t3.medium"
}

# Subdomains for services (ExternalDNS auto-creates these)
variable "grafana_subdomain" {
  type    = string
  default = "grafana"
}

variable "langfuse_subdomain" {
  type    = string
  default = "langfuse"
}



variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "kong-platform"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"] # bumped from t3.medium for observability stack headroom
}

variable "node_desired_size" {
  type    = number
  default = 4
}

variable "node_min_size" {
  type    = number
  default = 4
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "app_subdomain" {
  description = "Subdomain prefix for the application (e.g. 'app' -> app.<labid>.realhandsonlabs.net)"
  type        = string
  default     = "app"
}

variable "enable_tls" {
  description = "Enable SSL/TLS termination at the ALB"
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "create_acm_certificate" {
  description = "Whether to create/manage an ACM certificate via Terraform"
  type        = bool
  default     = true
}

