provider "aws" {
  region = var.region
}

module "egress_proxy" {
  source = "../../"

  config_bucket = {
    id  = aws_s3_bucket.asset.id
    arn = aws_s3_bucket.asset.arn
  }
  kms_key = data.aws_kms_alias.s3.target_key_arn

  ecs_cluster            = aws_ecs_cluster.example.id
  image                  = var.container_image
  vpc_name               = var.vpc_name
  subnet_names           = var.subnet_names
  parent_domain          = var.parent_domain
  size                   = 1
  use_s3_vpc_endpoint    = true
  env                    = var.env
  enable_execute_command = true

  acl = {
    sources = {
      my_private_range = [
        "10.0.0.0/8",
      ]
    }
    destinations = {
      httpbin = templatefile("${path.module}/config/example_allowlist.tpl", {
        httpbin = var.httpbin_host
      })
      idp = file("${path.module}/config/allowlist_identity_providers.tpl")
    }
    rules = [
      {
        source      = "my_private_range"
        destination = "httpbin"
      },
      {
        source      = "my_private_range"
        destination = "idp"
      }
    ]
  }
}

resource "aws_s3_bucket" "asset" {
  bucket        = "egress-proxy-asset-bucket"
  force_destroy = true
}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}
