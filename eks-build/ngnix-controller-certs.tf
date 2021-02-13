resource "aws_acm_certificate" "nginx" {
  domain_name       = "${var.cluster-name}.${var.eks-hosted-dnszone}"
  validation_method = "DNS"
  subject_alternative_names = ["prometheus.${var.cluster-name}.${var.eks-hosted-dnszone}","grafana.${var.cluster-name}.${var.eks-hosted-dnszone}","pushgateway.${var.cluster-name}.${var.eks-hosted-dnszone}","argo.${var.cluster-name}.${var.eks-hosted-dnszone}","*.${var.cluster-name}.${var.eks-hosted-dnszone}"]
  tags = {
    "Name"= "${var.cluster-name}-nginx-controller",
    "kubernetes.io/cluster/${var.cluster-name}"= "owned",
    "cluster-name"= var.cluster-name
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "k8" {
  name = var.eks-hosted-dnszone
  private_zone = false
}

resource "aws_route53_record" "nginx-certs" {
  for_each = {
  for dvo in aws_acm_certificate.nginx.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
  }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.k8.zone_id
}

resource "aws_acm_certificate_validation" "nginx-certs" {
  certificate_arn         = aws_acm_certificate.nginx.arn
  validation_record_fqdns = [for record in aws_route53_record.nginx-certs : record.fqdn]
}
