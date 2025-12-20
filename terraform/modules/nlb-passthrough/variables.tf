variable "region" {
  description = "Region for regional resources in the NLB fixture."
  type        = string
}

variable "zone" {
  description = "Zone used for zonal resources in the NLB fixture."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix applied to all resources in the NLB fixture."
  type        = string
}

variable "scenario" {
  description = "Fixture scenario identifier used for resource names."
  type        = string
}
