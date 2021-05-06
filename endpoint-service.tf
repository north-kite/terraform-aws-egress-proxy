resource "aws_vpc_endpoint_service" "internet_proxy" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.container_internet_proxy.arn]
  tags                       = local.common_tags
}

resource "aws_vpc_endpoint_service_allowed_principal" "managed_envs" {
  count                   = length(lookup(local.mgmt_account_mapping, local.environment))
  vpc_endpoint_service_id = aws_vpc_endpoint_service.internet_proxy.id
  principal_arn           = format("arn:aws:iam::%s:root", lookup(local.account, element(local.mgmt_account_mapping[local.environment], count.index)))
}

resource "aws_vpc_endpoint_service_allowed_principal" "management" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.internet_proxy.id
  principal_arn           = format("arn:aws:iam::%s:root", lookup(local.account, local.environment))
}


