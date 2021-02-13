data "kubernetes_ingress" "argo" {
  metadata {
    name = "argo-server-ingress"
    namespace = var.argo-ns
  }
}

resource "aws_route53_record" "argo" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "argo.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.argo.load_balancer_ingress.0.hostname]
}
