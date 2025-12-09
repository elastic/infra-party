locals {
  selected_scenario           = var.scenario
  is_vpc_flow                 = local.selected_scenario == "vpc-flow"
  is_nlb                      = local.selected_scenario == "nlb"
  is_alb                      = local.selected_scenario == "alb"
  is_nlb_passthrough          = local.selected_scenario == "nlb-passthrough"
  is_nlb_passthrough_internal = local.selected_scenario == "nlb-passthrough-internal"
}

module "vpc_flow" {
  source = "./modules/vpc-flow"
  count  = local.is_vpc_flow ? 1 : 0

  region          = var.region
  zone            = var.zone
  resource_prefix = var.resource_prefix
  scenario        = var.scenario
}

module "nlb" {
  source = "./modules/nlb"
  count  = local.is_nlb ? 1 : 0

  region          = var.region
  zone            = var.zone
  resource_prefix = var.resource_prefix
  scenario        = var.scenario
}

module "alb" {
  source = "./modules/alb"
  count  = local.is_alb ? 1 : 0

  region              = var.region
  zone                = var.zone
  resource_prefix     = var.resource_prefix
  scenario            = var.scenario
  load_balancer_scope = var.load_balancer_scope
}

module "nlb_passthrough" {
  source = "./modules/nlb-passthrough"
  count  = local.is_nlb_passthrough ? 1 : 0

  region          = var.region
  zone            = var.zone
  resource_prefix = var.resource_prefix
  scenario        = var.scenario
}

module "nlb_passthrough_internal" {
  source = "./modules/nlb-passthrough-internal"
  count  = local.is_nlb_passthrough_internal ? 1 : 0

  region          = var.region
  zone            = var.zone
  resource_prefix = var.resource_prefix
  scenario        = var.scenario
}
