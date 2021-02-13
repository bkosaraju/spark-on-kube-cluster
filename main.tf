provider "aws" { region = "ap-southeast-2" }
module "root" {
  source = "./eks-build"
}

#module "kube-app" {
#  source = "./kube-app"
#  cluster-name = module.root.cluster-name
#}
