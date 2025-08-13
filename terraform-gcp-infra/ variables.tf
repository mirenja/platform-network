variable "project_id" {
  description = "The GCP project ID where resources will be deployed."
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud Run service and Artifact Registry."
  type        = string
}

variable "frontend_workspace" {
  description = "Terraform Cloud workspace for frontend"
  type        = string
}

variable "organization" {
  description = "Terraform Cloud organization"
  type        = string
}

variable "contact_api_workspace" {
  description = "Terraform Cloud workspace for backend"
  type        = string
}

variable "lb_hosts" {
  description = "List of hostnames that the load balancer will respond to"
  type        = list(string)
}

