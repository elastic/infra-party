locals {
  name_prefix                  = "${var.resource_prefix}-${var.scenario}"
  network_name                 = "${local.name_prefix}-network"
  subnet_name                  = "${local.name_prefix}-subnet"
  backend_template_name        = "${local.name_prefix}-backend-template"
  backend_mig_name             = "${local.name_prefix}-backend-mig"
  backend_base_instance_name   = "${local.name_prefix}-backend"
  client_instance_name         = "${local.name_prefix}-client"
  address_name                 = "${local.name_prefix}-${var.load_balancer_scope}-alb-ip"
  health_check_name            = "${local.name_prefix}-hc"
  backend_service_name         = "${local.name_prefix}-backend-service"
  url_map_name                 = "${local.name_prefix}-url-map"
  target_http_proxy_name       = "${local.name_prefix}-http-proxy"
  target_https_proxy_name      = "${local.name_prefix}-https-proxy"
  ssl_certificate_name         = "${local.name_prefix}-ssl-cert"
  forwarding_rule_name         = "${local.name_prefix}-forwarding-rule"
  firewall_internal_name       = "${local.name_prefix}-allow-internal"
  firewall_health_check_name   = "${local.name_prefix}-allow-hc"
  firewall_client_backend_name = "${local.name_prefix}-allow-client"
  firewall_ssh_name            = "${local.name_prefix}-allow-ssh"
  backend_tag                  = "${local.name_prefix}-backend"
  client_tag                   = "${local.name_prefix}-client"
  backend_port                 = 80
  backend_port_string          = tostring(80)
  lb_port                      = var.enable_tls ? 443 : 80
  lb_port_string               = tostring(local.lb_port)
  is_global                    = var.load_balancer_scope == "global"
  is_regional                  = var.load_balancer_scope == "regional"
}

resource "google_compute_network" "fixture_network" {
  name                    = local.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "fixture_subnet" {
  name          = local.subnet_name
  region        = var.region
  network       = google_compute_network.fixture_network.id
  ip_cidr_range = "10.20.0.0/20"
}

resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = local.is_regional ? 1 : 0
  name          = "${local.name_prefix}-proxy-subnet"
  region        = var.region
  network       = google_compute_network.fixture_network.id
  ip_cidr_range = "10.20.16.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_firewall" "fixture_internal" {
  name    = local.firewall_internal_name
  network = google_compute_network.fixture_network.name

  direction = "INGRESS"
  source_ranges = [
    "10.20.0.0/20",
  ]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "fixture_health_check" {
  name    = local.firewall_health_check_name
  network = google_compute_network.fixture_network.name

  direction = "INGRESS"
  source_ranges = [
    "0.0.0.0/0",
  ]
  target_tags = [
    local.backend_tag,
  ]

  allow {
    protocol = "tcp"
    ports    = [local.backend_port_string]
  }
}

resource "google_compute_firewall" "fixture_client_backend" {
  name    = local.firewall_client_backend_name
  network = google_compute_network.fixture_network.name

  direction = "INGRESS"
  source_tags = [
    local.client_tag,
  ]
  target_tags = [
    local.backend_tag,
  ]

  allow {
    protocol = "tcp"
    ports    = [local.backend_port_string]
  }
}

resource "google_compute_firewall" "fixture_ssh" {
  name    = local.firewall_ssh_name
  network = google_compute_network.fixture_network.name

  direction = "INGRESS"
  source_ranges = [
    "0.0.0.0/0",
  ]
  target_tags = [
    local.backend_tag,
    local.client_tag,
  ]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance_template" "backend_template" {
  name_prefix = "${local.backend_template_name}-"

  machine_type = "e2-standard-2"

  tags = [
    local.backend_tag,
  ]

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o Acquire::ForceIPv4=true update
    apt-get -o Acquire::ForceIPv4=true install -y -q nginx
  SCRIPT

  disk {
    auto_delete  = true
    boot         = true
    source_image = "projects/debian-cloud/global/images/family/debian-12"
  }

  network_interface {
    network    = google_compute_network.fixture_network.id
    subnetwork = google_compute_subnetwork.fixture_subnet.id
    access_config {
      # Enable outbound package installation and troubleshooting.
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "backend_mig" {
  name               = local.backend_mig_name
  base_instance_name = local.backend_base_instance_name
  zone               = var.zone
  target_size        = 2

  version {
    name              = "primary"
    instance_template = google_compute_instance_template.backend_template.self_link
  }

  named_port {
    name = "http"
    port = local.backend_port
  }
}

resource "google_compute_region_health_check" "backend" {
  count              = local.is_regional ? 1 : 0
  name               = local.health_check_name
  region             = var.region
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = local.backend_port
    request_path = var.health_check_path
  }

  log_config {
    enable = true
  }

  healthy_threshold   = 2
  unhealthy_threshold = 2
}

resource "google_compute_health_check" "backend" {
  count              = local.is_global ? 1 : 0
  name               = local.health_check_name
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = local.backend_port
    request_path = var.health_check_path
  }

  log_config {
    enable = true
  }

  healthy_threshold   = 2
  unhealthy_threshold = 2
}

resource "google_compute_region_backend_service" "alb_backend" {
  count                 = local.is_regional ? 1 : 0
  name                  = local.backend_service_name
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  port_name             = "http"
  enable_cdn            = var.enable_cdn
  health_checks = [
    google_compute_region_health_check.backend[0].id,
  ]

  backend {
    group           = google_compute_instance_group_manager.backend_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  connection_draining_timeout_sec = 10

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
    optional_mode = var.enable_tls ? "CUSTOM" : null
    optional_fields = var.enable_tls ? [
      "tls.protocol",
      "tls.cipher"
    ] : []
  }
}

resource "google_compute_backend_service" "alb_backend" {
  count                 = local.is_global ? 1 : 0
  name                  = local.backend_service_name
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  port_name             = "http"
  enable_cdn            = var.enable_cdn
  health_checks = [
    google_compute_health_check.backend[0].id,
  ]

  backend {
    group           = google_compute_instance_group_manager.backend_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  connection_draining_timeout_sec = 10

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
    optional_mode = var.enable_tls ? "CUSTOM" : null
    optional_fields = var.enable_tls ? [
      "tls.protocol",
      "tls.cipher"
    ] : []
  }
}

resource "google_compute_address" "alb_ip" {
  count        = local.is_regional ? 1 : 0
  name         = local.address_name
  region       = var.region
  network_tier = "STANDARD"
}

resource "google_compute_global_address" "alb_ip" {
  count = local.is_global ? 1 : 0
  name  = local.address_name
}

# Self-signed TLS certificate for HTTPS
resource "tls_private_key" "alb_key" {
  count     = var.enable_tls ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  count           = var.enable_tls ? 1 : 0
  private_key_pem = tls_private_key.alb_key[0].private_key_pem

  subject {
    common_name  = var.tls_domain
    organization = "GCP Fixture Test"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Regional SSL certificate
resource "google_compute_region_ssl_certificate" "alb_cert" {
  count       = local.is_regional && var.enable_tls ? 1 : 0
  name        = local.ssl_certificate_name
  region      = var.region
  private_key = tls_private_key.alb_key[0].private_key_pem
  certificate = tls_self_signed_cert.alb_cert[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

# Global SSL certificate
resource "google_compute_ssl_certificate" "alb_cert" {
  count       = local.is_global && var.enable_tls ? 1 : 0
  name        = local.ssl_certificate_name
  private_key = tls_private_key.alb_key[0].private_key_pem
  certificate = tls_self_signed_cert.alb_cert[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_url_map" "alb_url_map" {
  count           = local.is_regional ? 1 : 0
  name            = local.url_map_name
  region          = var.region
  default_service = google_compute_region_backend_service.alb_backend[0].id
}

resource "google_compute_url_map" "alb_url_map" {
  count           = local.is_global ? 1 : 0
  name            = local.url_map_name
  default_service = google_compute_backend_service.alb_backend[0].id
}

resource "google_compute_region_target_http_proxy" "alb_proxy" {
  count   = local.is_regional && !var.enable_tls ? 1 : 0
  name    = local.target_http_proxy_name
  region  = var.region
  url_map = google_compute_region_url_map.alb_url_map[0].id
}

resource "google_compute_region_target_https_proxy" "alb_proxy" {
  count            = local.is_regional && var.enable_tls ? 1 : 0
  name             = local.target_https_proxy_name
  region           = var.region
  url_map          = google_compute_region_url_map.alb_url_map[0].id
  ssl_certificates = [google_compute_region_ssl_certificate.alb_cert[0].id]
}

resource "google_compute_target_http_proxy" "alb_proxy" {
  count   = local.is_global && !var.enable_tls ? 1 : 0
  name    = local.target_http_proxy_name
  url_map = google_compute_url_map.alb_url_map[0].id
}

resource "google_compute_target_https_proxy" "alb_proxy" {
  count            = local.is_global && var.enable_tls ? 1 : 0
  name             = local.target_https_proxy_name
  url_map          = google_compute_url_map.alb_url_map[0].id
  ssl_certificates = [google_compute_ssl_certificate.alb_cert[0].id]
}

resource "google_compute_forwarding_rule" "alb" {
  count                 = local.is_regional ? 1 : 0
  name                  = local.forwarding_rule_name
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = local.lb_port_string
  target                = var.enable_tls ? google_compute_region_target_https_proxy.alb_proxy[0].id : google_compute_region_target_http_proxy.alb_proxy[0].id
  ip_address            = google_compute_address.alb_ip[0].address
  network_tier          = "STANDARD"
  network               = google_compute_network.fixture_network.id
  # Proxy-only subnet is auto-discovered by GCP based on network and region

  depends_on = [google_compute_subnetwork.proxy_only_subnet]
}

resource "google_compute_global_forwarding_rule" "alb" {
  count                 = local.is_global ? 1 : 0
  name                  = local.forwarding_rule_name
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = local.lb_port_string
  target                = var.enable_tls ? google_compute_target_https_proxy.alb_proxy[0].id : google_compute_target_http_proxy.alb_proxy[0].id
  ip_address            = google_compute_global_address.alb_ip[0].address
}

resource "google_compute_instance" "client" {
  name         = local.client_instance_name
  zone         = var.zone
  machine_type = "e2-micro"

  tags = [
    local.client_tag,
  ]

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o Acquire::ForceIPv4=true update
    apt-get -o Acquire::ForceIPv4=true install -y -q iperf3 curl netcat-openbsd
  SCRIPT

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.fixture_network.id
    subnetwork = google_compute_subnetwork.fixture_subnet.id
    access_config {}
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

