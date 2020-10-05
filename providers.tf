#
# Provider Configuration
#

provider "aws" { region = "ap-southeast-2" }
provider "http" {}

//provider "kubernetes" {
//  load_config_file       = false
//  version                = "1.10.0"
//  alias                  = "override"
//  host                   = aws_eks_cluster.cluster.endpoint
//  config_path            = local_file.kubeconfig.filename
//}

#provider "kubernetes" {
#host = aws_eks_cluster.cluster.endpoint
#load_config_file = true
#version         = "1.10.0"
#//config_path = local_file.kubeconfig.filename
#// = aws_eks_cluster.cluster.certificate_authority.0.data
## Using these data sources allows the configuration to be
# generic for any region.

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


