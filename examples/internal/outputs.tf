output "proxy_address" {
  value = module.egress_proxy.proxy_address
}

output "proxy_port" {
  value = module.egress_proxy.proxy_port
}

output "httpbin_host" {
  value = var.httpbin_host
}
