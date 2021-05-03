#VPC specific configuration
variable "vpc_cidr_blocks" {
  default = "10.0.0.0/16"
  type    = string
}
variable "vpc_az_cidrs_private" {
  default = ["10.0.1.0/24","10.0.2.0/24"]
  type    = list(string)
}
variable "vpc_az_cidrs_public" {
  default = ["10.0.3.0/24","10.0.4.0/24"]
  type    = list(string)
}

variable "vpc_az_cidrs_elb" {
  default = "10.0.4.0/24"
  type    = string
}

variable "vpc_az_count" {
  default = 2
  type    = number
}

variable "bastion-instance-type" {
  default = "t3.medium"
  type    = string
}

#Cluster specific configuration
variable "cluster-name" {
  default = "eks-dm-dev"
  type    = string
}

variable "cluster-api-public-access-cidrs" {
  default = ["203.6.223.18/32","13.239.82.145/32","13.55.91.180/32"]
  type = set(string)
}
#Worker specific configuration
variable "worker-instance-type" {
  default = "r5.2xlarge"
  type    = string
}

variable "worker-ebs-volume-size" {
  default = "300"
  type    = number
}


variable "worker-max-instances" {
  default = 11
  type    = number
}

variable "worker-instances-cooldown-duration" {
  default = 600
  type    = number
  description = "Ammount of time to auto terminate instance when there is no activity"
}

#Application Specific configuration
variable "application-namespace" {
 default = "datamarvels"
 type   = string
}

variable "application-serviceaccount" {
  default = "app-robot-user"
  type   = string
}

variable "application-s3-bucket" {
  default = "imf-config"
  type = string
}

variable "application-s3-bucket-kms-key" {
  default = "imf-s3-kms"
  type = string
}

#Prometheous configuration

variable "prometheus-ns" {
  default = "prometheus"
  type   = string
}

variable "grafana-ns" {
  default = "grafana"
  type   = string
}

variable "grafana-admin-temp-password" {
  default = "nimda"
  type = string
}
# Argo configuration 


variable "argo-s3-bucket" {
  default = "imf-argo-artifacts"
  type = string
}


variable "argo-version" {
 default = "v3.0.1"
 type   = string
}

variable "argo-ns" {
 default = "argo"
 type   = string
}


variable "argo-s3-bucket-kms-key" {
  default = "imf-s3-kms"
  type = string
}

variable "eks-hosted-dnszone" {
  default = "datamarvels.com"
  type = string
}

variable "spark-hs-image" {
  default = "991267008870.dkr.ecr.ap-southeast-2.amazonaws.com/imf/de:2.12_3.0.1_1.19"
  type = string
}

variable "spark-hs-location" {
  default = "s3a://imf-config/spark-hs/event-log"
  type = string
}

variable "dashboard-ns" {
  default = "kubernetes-dashboard"
  type = string
}


variable "kubeflow-ns" {
  default = "kubeflow"
  type = string
}

