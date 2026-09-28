# =============================================================
# Auto-discover the lab hosted zone (assumes exactly ONE zone)
# =============================================================
data "aws_route53_zones" "all" {}

data "aws_route53_zone" "lab" {
  zone_id = one(data.aws_route53_zones.all.ids)
}

locals {
  # e.g. "381491852311.realhandsonlabs.net"
  lab_domain  = trimsuffix(data.aws_route53_zone.lab.name, ".")
  lab_zone_id = data.aws_route53_zone.lab.zone_id

  # Application hostname (subdomain of the lab zone)
  # e.g. "app.381491852311.realhandsonlabs.net"
  app_hostname = "${var.app_subdomain}.${local.lab_domain}"
}

# =============================================================
# ACM certificate for the lab domain + wildcard
#   - Created only when create_acm_certificate = true
#     AND no existing acm_certificate_arn is provided
# =============================================================
resource "aws_acm_certificate" "this" {
  count = var.create_acm_certificate && var.acm_certificate_arn == "" ? 1 : 0

  domain_name       = local.lab_domain # 381491852311.realhandsonlabs.net
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${local.lab_domain}" # *.381491852311.realhandsonlabs.net
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-cert"
  }
}

# DNS validation records created automatically in the discovered zone
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_certificate && var.acm_certificate_arn == "" ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = local.lab_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Waits until the certificate is validated (usually 1-3 minutes)
resource "aws_acm_certificate_validation" "this" {
  count = var.create_acm_certificate && var.acm_certificate_arn == "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# =============================================================
# Resolve which certificate ARN to use
#   - Existing ARN if provided
#   - Otherwise the one we just created + validated
# =============================================================
locals {
  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (
    var.create_acm_certificate ? aws_acm_certificate_validation.this[0].certificate_arn : ""
  )
}

