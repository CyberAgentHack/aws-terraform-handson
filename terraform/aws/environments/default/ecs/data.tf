data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = "myproject-terraform-state"                # Replace with your team name
    key     = "network/terraform.tfstate" # Replace with your team name
    region  = "ap-northeast-1"
    profile = "default"
  }
}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket  = "myproject-terraform-state"            # Replace with your team name
    key     = "ecr/terraform.tfstate" # Replace with your team name
    region  = "ap-northeast-1"
    profile = "default"
  }
}

# Add remote state for database
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = "myproject-terraform-state"                 # Replace with your team name
    key     = "database/terraform.tfstate" # Replace with your team name
    region  = "ap-northeast-1"
    profile = "default"
  }
}

