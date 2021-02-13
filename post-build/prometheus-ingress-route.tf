data "kubernetes_ingress" "ps" {
  metadata {
    name = "prometheus-server"
    namespace = var.prometheus-ns
  }
}
data "kubernetes_ingress" "ppg" {
  metadata {
    name = "prometheus-pushgateway"
    namespace = var.prometheus-ns
  }
}
resource "aws_route53_record" "ps" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "prometheus.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.ps.load_balancer_ingress.0.hostname]
}

resource "aws_route53_record" "ppg" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "pushgateway.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.ppg.load_balancer_ingress.0.hostname]
}
