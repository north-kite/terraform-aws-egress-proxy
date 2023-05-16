data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

data "aws_route53_zone" "private" {
  name         = var.parent_domain
  private_zone = true
}

data "aws_route53_zone" "public" {
  name         = var.parent_domain
  private_zone = false
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "subnets" {
  count = length(var.subnet_names)

  filter {
    name   = "tag:Name"
    values = [element(var.subnet_names, count.index)]
  }
}

data "aws_vpc_endpoint" "s3" {
  count        = var.use_s3_vpc_endpoint ? 1 : 0
  vpc_id       = data.aws_vpc.vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

data "aws_iam_role" "ecs_task_execution_role" {
  count = var.ecs_task_execution_role != null ? 1 : 0
  name  = var.ecs_task_execution_role
}
