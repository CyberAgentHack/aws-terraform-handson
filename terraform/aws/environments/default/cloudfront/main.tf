locals {
  app_prefix = "book-shelf"
}

module "cloudfront" {
  source = "../../../modules/cloudfront"

  environment  = var.environment
  app_name     = "${local.app_prefix}-${var.app_name}"
  alb_dns_name = data.terraform_remote_state.ecs.outputs.alb_dns_name
}
