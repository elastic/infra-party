output "region" {
  description = "Region where the internal network load balancer is deployed."
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
  description = "Forwarding rule name for the internal network load balancer."
  value       = google_compute_forwarding_rule.nlb.name
}

output "forwarding_rule_ip" {
  description = "Internal IP address assigned to the network load balancer."
  value       = google_compute_address.nlb_ip.address
}

output "subnet_name" {
  description = "Subnet associated with the fixtures for filtering load balancer logs."
  value       = google_compute_subnetwork.fixture_subnet.name
}

output "backend_service_name" {
  description = "Backend service name for the internal network load balancer."
  value       = google_compute_region_backend_service.nlb_backend.name
}

output "network_name" {
  description = "VPC network name where the internal load balancer is deployed."
  value       = google_compute_network.fixture_network.name
}

