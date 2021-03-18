data "kubernetes_ingress" "dashboard" {
  metadata {
    name = "dashboard-ingress"
    namespace = var.dashboard-ns
  }
}

resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "dashboard.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.dashboard.load_balancer_ingress.0.hostname]
}
