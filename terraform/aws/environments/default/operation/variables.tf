variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Project   = "handson" # Replace with your team name
    ManagedBy = "terraform"
  }
}
