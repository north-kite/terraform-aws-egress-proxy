# Required Variables

variable "env" {
  description = "Environment name, used in resource names (e.g. dev, stage, prod)"
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

variable "ecs_cluster" {
  description = "ARN of ECS cluster to deploy to"
  type        = string
}

variable "config_bucket" {
  description = "ID and ARN of an S3 bucket to store egress proxy config files in."
  type = object({
    id  = string
    arn = string
  })
}

variable "parent_domain" {
  description = "Domain name under which `sub_domain` will be added. Requires both public and private Hosted Zones to exist in Route 53" # TODO supporting http would make public optional
  type        = string
}

variable "acl" {
  description = "Access control lists for proxy. `sources` is a map of sources allowed (IPs, CIDRs, or hosts). `destinations` is a map groups of destinations, typically supplied via `file` or `templatefile` function (see module examples). `rules` is a map of `sources` to `destinations`. Refer to Squid ACl docs for further details: http://www.squid-cache.org/Doc/config/acl/"
  type = object({
    sources      = map(list(string))
    destinations = map(string)
    rules        = list(map(string))
  })
}

# Optional Variables

variable "kms_key" {
  description = "(Optional) KMS key used for encrypting S3 `config_bucket`. Used to encrypt config files and grant access in container IAM role"
  type        = string
  default     = null
}

variable "service" {
  description = "(Optional) Service name, used in resource names"
  type        = string
  default     = ""
}

variable "role" {
  description = "(Optional) Used to segment instantiations of the same project egress in an account, used in resource names"
  type        = string
  default     = "egress-proxy"
}

variable "image" {
  description = "(Optional) Container image to use in the standard form of `<registry>/<repository>:<tag>@<digest>` where `tag` and `digest` are optional and `registry` defaults to Docker Hub"
  type        = string
  default     = "dwpdigital/squid-s3:latest"
}

variable "proxy_port" {
  description = "(Optional) Port for addressing egress proxy."
  type        = number
  default     = 3128
}

variable "ecs_launch_type" {
  description = "(Optional) The launch type on which to run your service. The valid values are `EC2`, `FARGATE`, and `EXTERNAL`. Defaults to `FARGATE`."
  type        = string
  default     = "FARGATE"
}

variable "size" {
  description = "(Optional) Number of containers to run. Defaults to match the number of availability zones in region."
  type        = number
  default     = null
}

variable "use_s3_vpc_endpoint" {
  description = "(Optional) Set to `true` to have connectivity to S3 use an existing VPC endpoint"
  type        = bool
  default     = false
}

variable "load_balancer_access_log_bucket_id" {
  description = "(Optional) ID of an S3 bucket to store load balancer logs in."
  type        = string
  default     = null
}

variable "ecs_task_execution_role" {
  description = "(Optional) Name of existing IAM role for ECS task execution, which will need the `AmazonECSTaskExecutionRolePolicy` policy attached. If not provided, the module will create a new role."
  type        = string
  default     = null
}

variable "subdomain" {
  description = "(Optional) Subdomain to prepend to `parent_domain` to form domain name for proxy"
  type        = string
  default     = "proxy"
}

variable "enable_execute_command" {
  description = "(Optional) Define whether to enable Amazon ECS Exec for tasks within the service."
  type        = bool
  default     = false
}

variable "ingress_network_access" {
  description = "(Optional) List of CIDRs that have access to the proxy. Defaults to standard internal CIDRs."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "squid_config_s3_main_prefix" {
  description = "(Optional) Prefix for creating config files in S3"
  type        = string
  default     = "egress-proxy"
}

variable "egress_network_access" {
  description = "(Optional) List of CIDRs that the proxy can access. Defaults to anywhere."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "egress_network_ports" {
  description = "(Optional) List of ports that the proxy can access. Defaults to `80` and `443`."
  type        = set(number)
  default     = [80, 443]
}
