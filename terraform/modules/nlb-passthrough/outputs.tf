output "region" {
  description = "Region where the network load balancer is deployed."
  value       = var.region
}

output "zone" {
  description = "Zone hosting zonal resources such as the backend instance group."
  value       = var.zone
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
  description = "Forwarding rule name for the network load balancer."
  value       = google_compute_forwarding_rule.nlb.name
}

output "forwarding_rule_ip" {
  description = "External IP address assigned to the network load balancer."
  value       = google_compute_address.nlb_ip.address
}

output "subnet_name" {
  description = "Subnet associated with the fixtures for filtering load balancer logs."
  value       = google_compute_subnetwork.fixture_subnet.name
}

output "backend_service_name" {
  description = "Backend service name for the network load balancer."
  value       = google_compute_region_backend_service.nlb_backend.name
}

