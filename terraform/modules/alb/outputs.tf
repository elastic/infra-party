output "region" {
  description = "Region where the regional external application load balancer is deployed."
  value       = var.region
}

output "zone" {
  description = "Zone hosting zonal resources such as the backend instance group."
  value       = var.zone
}

output "load_balancer_scope" {
  description = "Scope of the application load balancer (global or regional)."
  value       = var.load_balancer_scope
}

output "enable_tls" {
  description = "Whether TLS/HTTPS is enabled on the load balancer."
  value       = var.enable_tls
}

output "backend_mig_name" {
  description = "Name of the backend managed instance group."
  value       = google_compute_instance_group_manager.backend_mig.name
}

output "client_instance_name" {
  description = "Name of the client VM used to generate load balancer traffic."
  value       = google_compute_instance.client.name
}

output "forwarding_rule_name" {
  description = "Forwarding rule name for the application load balancer."
  value       = var.load_balancer_scope == "regional" ? google_compute_forwarding_rule.alb[0].name : google_compute_global_forwarding_rule.alb[0].name
}

output "forwarding_rule_ip" {
  description = "External IP address assigned to the application load balancer."
  value       = var.load_balancer_scope == "regional" ? google_compute_address.alb_ip[0].address : google_compute_global_address.alb_ip[0].address
}

output "subnet_name" {
  description = "Subnet associated with the fixtures for filtering load balancer logs."
  value       = google_compute_subnetwork.fixture_subnet.name
}

output "backend_service_name" {
  description = "Backend service name for the application load balancer."
  value       = var.load_balancer_scope == "regional" ? google_compute_region_backend_service.alb_backend[0].name : google_compute_backend_service.alb_backend[0].name
}

output "url_map_name" {
  description = "URL map name for the application load balancer."
  value       = var.load_balancer_scope == "regional" ? google_compute_region_url_map.alb_url_map[0].name : google_compute_url_map.alb_url_map[0].name
}

output "target_proxy_name" {
  description = "Target proxy name for the application load balancer."
  value = var.enable_tls ? (
    var.load_balancer_scope == "regional" ? google_compute_region_target_https_proxy.alb_proxy[0].name : google_compute_target_https_proxy.alb_proxy[0].name
  ) : (
    var.load_balancer_scope == "regional" ? google_compute_region_target_http_proxy.alb_proxy[0].name : google_compute_target_http_proxy.alb_proxy[0].name
  )
}

output "load_balancer_url" {
  description = "URL to access the application load balancer."
  value = var.enable_tls ? (
    var.load_balancer_scope == "regional" ? "https://${google_compute_address.alb_ip[0].address}" : "https://${google_compute_global_address.alb_ip[0].address}"
  ) : (
    var.load_balancer_scope == "regional" ? "http://${google_compute_address.alb_ip[0].address}" : "http://${google_compute_global_address.alb_ip[0].address}"
  )
}

