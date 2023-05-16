variable "region" {
  description = "The name of an AWS region"
  type        = string
}

variable "env" {
  description = "(Optional) Resource environment tag (i.e. dev, stage, prod)"
  type        = string
  default     = "test"
}

variable "service" {
  description = "(Optional) Resource service tag"
  type        = string
  default     = "egress-proxy"
}

variable "parent_domain" {
  description = "Domain name under which `sub_domain` will be added. Requires both public and private Hosted Zones to exist in Route 53"
  type        = string
}

variable "vpc_name" {
  description = "VPC that resources should be deployed to"
  type        = string
}
variable "subnet_names" {
  description = "Subnets that resources should be deployed in"
  type        = list(string)
}

variable "container_image" {
  description = "(Optional) Container image to use in the standard form of `<registry>/<repository>:<tag>@<digest>` where `tag` and `digest` are optional and `registry` defaults to Docker Hub"
  type        = string
  default     = "dwpdigital/squid-s3:latest"
}

variable "httpbin_host" {
  description = "(Optional) Hostname of httpbin to use in testing"
  type        = string
  default     = "httpbin.org"
}
