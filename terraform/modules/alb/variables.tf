variable "region" {
  description = "Region for regional resources in the alb fixture."
  type        = string
}

variable "zone" {
  description = "Zone used for zonal resources in the alb fixture."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix applied to all resources in the alb fixture."
  type        = string
}

variable "scenario" {
  description = "Fixture scenario identifier used for resource names."
  type        = string
}

variable "load_balancer_scope" {
  description = "Scope of the application load balancer: 'global' or 'regional'."
  type        = string
  default     = "regional"
  validation {
    condition     = contains(["global", "regional"], var.load_balancer_scope)
    error_message = "load_balancer_scope must be either 'global' or 'regional'."
  }
}

variable "health_check_path" {
  description = "HTTP path for health check requests."
  type        = string
  default     = "/"
}

variable "enable_cdn" {
  description = "Enable Cloud CDN on the backend service."
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "Enable request/response logging on the load balancer."
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sample rate for load balancer logs (0.0 to 1.0)."
  type        = number
  default     = 1.0
}

variable "enable_tls" {
  description = "Enable TLS/HTTPS on the load balancer."
  type        = bool
  default     = true
}

variable "tls_domain" {
  description = "Domain name for the TLS certificate (used for self-signed certificate)."
  type        = string
  default     = "example.com"
}

