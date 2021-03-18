data "kubernetes_ingress" "spark-hs" {
  metadata {
    name = "spark-history-server"
    namespace = var.application-namespace
  }
}

resource "aws_route53_record" "spark-hs" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "spark.${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_ingress.spark-hs.load_balancer_ingress.0.hostname]
}
