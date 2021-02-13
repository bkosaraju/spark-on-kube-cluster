data "aws_route53_zone" "k8" {
  name = var.eks-hosted-dnszone
    private_zone = false
}


data "kubernetes_service" "ingress" {
  metadata {
    name = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

resource "aws_route53_record" "ingress" {
  zone_id = data.aws_route53_zone.k8.zone_id
  name    = "${var.cluster-name}.${var.eks-hosted-dnszone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.ingress.load_balancer_ingress.0.hostname]
}

