variable "environment" {
  description = "Environment name (dev, stg, prod, etc.)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name to use as CloudFront origin"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to resources"
  type        = map(string)
  default     = {}
}
