terraform {
  required_version = "~> 0.12.0"

}

data "terraform_remote_state" "management" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {}
}

data "terraform_remote_state" "management_dns" {
  backend   = "s3"
  workspace = "management"

  config = {}
}

data "terraform_remote_state" "internet_ingress" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {}
}

data "terraform_remote_state" "security_tools" {
  backend   = "s3"
  workspace = local.environment

  config = {}
}

variable "assume_role" {
  default = "ci"
}

variable "region" {
  default = "eu-west-2"
}

provider "aws" {
  version = "~> 2.62.0"
  region  = var.region

  assume_role {
    role_arn = "arn:aws:iam::${local.account[local.environment]}:role/${var.assume_role}"
  }
}

provider "aws" {
  version = "~> 2.62.0"
  region  = var.region
  alias   = "management"

  assume_role {
    role_arn = "arn:aws:iam::${local.account["management"]}:role/${var.assume_role}"
  }
}

provider "aws" {
  version = "~> 2.62.0"
  region  = var.region
  alias   = "management_dns"

  assume_role {
    role_arn = "arn:aws:iam::${local.account["management"]}:role/${var.assume_role}"
  }
}

// Get AWS Account ID for credentials in use
data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
}
