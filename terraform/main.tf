locals {
  selected_scenario = var.scenario
  is_vpc_flow       = local.selected_scenario == "vpc-flow"
  is_nlb            = local.selected_scenario == "nlb"
  is_alb           = local.selected_scenario == "alb"
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

  region                = var.region
  zone                  = var.zone
  resource_prefix       = var.resource_prefix
  scenario              = var.scenario
  load_balancer_scope   = var.load_balancer_scope
}
