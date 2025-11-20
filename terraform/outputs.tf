locals {
  has_vpc_flow = length(module.vpc_flow) > 0
  has_nlb      = length(module.nlb) > 0
  has_alb     = length(module.alb) > 0
}

output "scenario" {
  description = "Selected fixture scenario."
  value       = var.scenario
}

output "region" {
  description = "Region where primary resources are deployed."
  value       = var.region
}

output "zone" {
  description = "Zone used for zonal resources."
  value       = var.zone
}

output "mig_name" {
  description = "Managed instance group name for the VPC flow scenario."
  value       = local.has_vpc_flow ? module.vpc_flow[0].mig_name : null
}

output "subnet_name" {
  description = "Subnet used for log filtering."
  value       = local.has_vpc_flow ? module.vpc_flow[0].subnet_name : local.has_nlb ? module.nlb[0].subnet_name : local.has_alb ? module.alb[0].subnet_name : null
}

output "backend_mig_name" {
  description = "Backend managed instance group name for the NLB or alb scenario."
  value       = local.has_nlb ? module.nlb[0].backend_mig_name : local.has_alb ? module.alb[0].backend_mig_name : null
}

output "client_instance_name" {
  description = "Client VM name for the NLB or alb scenario."
  value       = local.has_nlb ? module.nlb[0].client_instance_name : local.has_alb ? module.alb[0].client_instance_name : null
}

output "forwarding_rule_name" {
  description = "Load balancer forwarding rule name."
  value       = local.has_nlb ? module.nlb[0].forwarding_rule_name : local.has_alb ? module.alb[0].forwarding_rule_name : null
}

output "forwarding_rule_ip" {
  description = "External IP assigned to the load balancer."
  value       = local.has_nlb ? module.nlb[0].forwarding_rule_ip : local.has_alb ? module.alb[0].forwarding_rule_ip : null
}

output "backend_service_name" {
  description = "Backend service name for the load balancer."
  value       = local.has_nlb ? module.nlb[0].backend_service_name : local.has_alb ? module.alb[0].backend_service_name : null
}

output "url_map_name" {
  description = "URL map name for the application load balancer."
  value       = local.has_alb ? module.alb[0].url_map_name : null
}

output "target_proxy_name" {
  description = "Target proxy name for the application load balancer."
  value       = local.has_alb ? module.alb[0].target_proxy_name : null
}

output "load_balancer_url" {
  description = "URL to access the application load balancer."
  value       = local.has_alb ? module.alb[0].load_balancer_url : null
}

output "load_balancer_scope" {
  description = "Scope of the application load balancer (global or regional)."
  value       = local.has_alb ? module.alb[0].load_balancer_scope : null
}

output "enable_tls" {
  description = "Whether TLS/HTTPS is enabled on the application load balancer."
  value       = local.has_alb ? module.alb[0].enable_tls : null
}

