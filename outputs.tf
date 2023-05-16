#output "internet_proxy_service" {
#  value = {
#    service_name = aws_vpc_endpoint_service.internet_proxy.service_name
#    lb_listener  = aws_lb_listener.container_internet_proxy_tls
#  }
#}

output "proxy_address" {
  value = aws_route53_record.egress_proxy.fqdn
}

output "proxy_port" {
  value = var.proxy_port
}
