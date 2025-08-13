data "terraform_remote_state" "frontend" {
  backend = "remote"
  config = {
    organization = var.organization
    workspaces = { name = var.frontend_workspace }
  }
}

data "terraform_remote_state" "contact_api" {
  backend = "remote"
  config = {
    organization = var.organization
    workspaces = { name = var.contact_api_workspace }
  }
}
##Reserve an external IP address
resource "google_compute_global_address" "lb_ip" {
  name         = "central-lb-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

##Create an SSL certificate resource
resource "google_compute_managed_ssl_certificate" "lb_cert" {
  provider = google-beta
  name = "central-lb-cert"

  managed {
    domains = var.lb_hosts
  } 
}

#setup NEG

resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "cloud-run-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = data.terraform_remote_state.frontend.outputs.cloud_run_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "cloud_function_neg" {
  name                  = "cloud-function-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    function = data.terraform_remote_state.contact_api.outputs.cloud_function_name
  }
}

#create backend service
resource "google_compute_backend_service" "cloud_run_backend" {
  name                  = "cloud-run-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }
}

resource "google_compute_backend_service" "cloud_function_backend" {
  name                  = "cloud-function-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_function_neg.id
  }
}


##URL map - routing rules

resource "google_compute_url_map" "lb_url_map" {
  name            = "central-url-map"
  default_service = google_compute_backend_service.cloud_run_backend.id

  host_rule {
    hosts        = var.lb_hosts
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.cloud_run_backend.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.cloud_function_backend.id
    }
  }
}

#Target HTTPS proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "central-https-proxy"
  url_map          = google_compute_url_map.lb_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert.id]
  http_keep_alive_timeout_sec  = 600
}


# Global forwarding rule - port 443
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name                  = "central-https-forwarding-rule"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
  load_balancing_scheme = "EXTERNAL"
}


##DNS- create an A record

resource "google_dns_managed_zone" "default_zone" {
  name        = "default-zone"
  dns_name    = "${var.lb_hosts[0]}."
  description = "default Public DNS zone"
  visibility  = "public"
  labels = {
    environment = "production"
    project     = var.project_id

  }
}

resource "random_id" "rnd" {
  byte_length = 4
}

##rr-resource records
resource "google_dns_record_set" "lb_dns" {
  for_each     = toset(var.lb_hosts)
  name         = "${each.key}."      
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default_zone.name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}
