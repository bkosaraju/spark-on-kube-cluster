data "kubernetes_ingress" "grafana" {
  metadata {
    name = "grafana"
    namespace = var.grafana-ns
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "grafana.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.grafana.load_balancer_ingress.0.hostname]
}
