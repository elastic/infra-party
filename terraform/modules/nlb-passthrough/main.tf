locals {
  name_prefix                  = "${var.resource_prefix}-nlb-passthrough"
  network_name                 = "${local.name_prefix}-network"
  subnet_name                  = "${local.name_prefix}-subnet"
  backend_template_name        = "${local.name_prefix}-backend-template"
  backend_mig_name             = "${local.name_prefix}-backend-mig"
  backend_base_instance_name   = "${local.name_prefix}-backend"
  client_instance_name         = "${local.name_prefix}-client"
  address_name                 = "${local.name_prefix}-nlb-ip"
  health_check_name            = "${local.name_prefix}-hc"
  backend_service_name         = "${local.name_prefix}-backend-service"
  forwarding_rule_name         = "${local.name_prefix}-forwarding-rule"
  firewall_internal_name       = "${local.name_prefix}-allow-internal"
  firewall_health_check_name   = "${local.name_prefix}-allow-hc"
  firewall_client_backend_name = "${local.name_prefix}-allow-client"
  firewall_ssh_name            = "${local.name_prefix}-allow-ssh"
  backend_tag                  = "${local.name_prefix}-backend"
  client_tag                   = "${local.name_prefix}-client"
  backend_port                 = 80
  backend_port_string          = tostring(80)
}

resource "google_compute_network" "fixture_network" {
  name                    = local.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "fixture_subnet" {
  name          = local.subnet_name
  region        = var.region
  network       = google_compute_network.fixture_network.id
  ip_cidr_range = "10.30.0.0/20"
}

resource "google_compute_firewall" "fixture_internal" {
  name          = local.firewall_internal_name
  network       = google_compute_network.fixture_network.name
  direction     = "INGRESS"
  source_ranges = ["10.30.0.0/20"]

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
  name          = local.firewall_health_check_name
  network       = google_compute_network.fixture_network.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.backend_tag]

  allow {
    protocol = "tcp"
    ports    = [local.backend_port_string]
  }
}

resource "google_compute_firewall" "fixture_client_backend" {
  name        = local.firewall_client_backend_name
  network     = google_compute_network.fixture_network.name
  direction   = "INGRESS"
  source_tags = [local.client_tag]
  target_tags = [local.backend_tag]

  allow {
    protocol = "tcp"
    ports    = [local.backend_port_string]
  }
}

resource "google_compute_firewall" "fixture_ssh" {
  name          = local.firewall_ssh_name
  network       = google_compute_network.fixture_network.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.backend_tag, local.client_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance_template" "backend_template" {
  name_prefix = "${local.backend_template_name}-"
  machine_type = "e2-standard-2"
  tags = [local.backend_tag]
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
    access_config {}
  }
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
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
  name               = local.health_check_name
  region             = var.region
  check_interval_sec = 10
  timeout_sec        = 5

  tcp_health_check {
    port = local.backend_port
  }

  log_config {
    enable = true
  }

  healthy_threshold   = 2
  unhealthy_threshold = 2
}

resource "google_compute_region_backend_service" "nlb_backend" {
  name                  = local.backend_service_name
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  port_name             = "http"
  health_checks         = [google_compute_region_health_check.backend.id]

  backend {
    group = google_compute_instance_group_manager.backend_mig.instance_group
    balancing_mode = "CONNECTION"
  }

  connection_draining_timeout_sec = 10

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_forwarding_rule" "nlb" {
  name                  = local.forwarding_rule_name
  region                = var.region
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
  port_range            = local.backend_port_string
  backend_service       = google_compute_region_backend_service.nlb_backend.id
  ip_address            = google_compute_address.nlb_ip.address
  network_tier          = "STANDARD"
}

resource "google_compute_address" "nlb_ip" {
  name         = local.address_name
  region       = var.region
  network_tier = "STANDARD"
}


resource "google_compute_instance" "client" {
  name         = local.client_instance_name
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = [local.client_tag]
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
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
