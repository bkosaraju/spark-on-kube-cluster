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
  default = "10.0.3.0/24"
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

variable "bastion_public_key" {
  default = "xxxxxxxx"
  type    = string
}


#Cluster specific configuration
variable "cluster-name" {
  default = "eks-de-dev"
  type    = string
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
 default = "dataengineering"
 type   = string
}

variable "application-serviceaccount" {
  default = "spark"
  type   = string
}

variable "application-s3-bucket" {
  default = "app-config"
  type = string
}

variable "application-s3-bucket-kms-key" {
  default = "app-s3-kms"
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
  default = "app-argo-artifacts"
  type = string
}


variable "argo-version" {
 default = "v2.9.3"
 type   = string
}

variable "argo-ns" {
 default = "argo"
 type   = string
}


variable "argo-s3-bucket-kms-key" {
  default = "app-s3-kms"
  type = string
}

