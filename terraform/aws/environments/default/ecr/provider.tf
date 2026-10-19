terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "myproject-terraform-state"            # Replace with your team name
    key     = "ecr/terraform.tfstate" # Replace with your team name
    region  = "ap-northeast-1"
    encrypt = true
    profile = "default"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = var.default_tags
  }
  profile = "default"
}
