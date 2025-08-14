output "lb_ip_address" {
  description = "Global IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "lb_url" {
  value = "https://${var.lb_hosts[0]}"
}

output "frontend_service_name" {
  description = "Cloud Run service name from frontend workspace"
  value       = data.terraform_remote_state.frontend.outputs.service_name
}

output "backend_function_name" {
  description = "Cloud Function name from backend workspace"
  value       = data.terraform_remote_state.contact_api.outputs.cloud_function_name
}
