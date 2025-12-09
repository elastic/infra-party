variable "project_id" {
  description = "Google Cloud project ID where fixture infrastructure will be created."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must be a non-empty string."
  }
}

variable "region" {
  description = "Google Cloud region used for regional resources such as the managed instance group."
  type        = string

  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "region must be a non-empty string."
  }
}

variable "zone" {
  description = "Default Google Cloud zone used for zonal API operations (e.g., instance metadata updates)."
  type        = string

  validation {
    condition     = length(trimspace(var.zone)) > 0
    error_message = "zone must be a non-empty string."
  }
}

variable "resource_prefix" {
  description = "Prefix applied to all fixture infrastructure resources."
  type        = string
  default     = "gcp-fixture"

  validation {
    condition     = length(trimspace(var.resource_prefix)) > 0
    error_message = "resource_prefix cannot be empty."
  }
}

variable "scenario" {
  description = "Fixture scenario to deploy. Supported values: \"vpc-flow\", \"nlb\", \"alb\", \"nlb-passthrough\", \"nlb-passthrough-internal\"."
  type        = string
  default     = "vpc-flow"

  validation {
    condition     = contains(["vpc-flow", "nlb", "alb", "nlb-passthrough", "nlb-passthrough-internal"], var.scenario)
    error_message = "scenario must be one of: vpc-flow, nlb, alb, nlb-passthrough, nlb-passthrough-internal."
  }
}

variable "load_balancer_scope" {
  description = "Scope for the application load balancer (alb scenario only). Supported values: \"global\", \"regional\"."
  type        = string
  default     = "regional"

  validation {
    condition     = contains(["global", "regional"], var.load_balancer_scope)
    error_message = "load_balancer_scope must be either 'global' or 'regional'."
  }
}

