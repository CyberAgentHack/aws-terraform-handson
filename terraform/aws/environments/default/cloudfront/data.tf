data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket  = "myproject-terraform-state"                      # Replace with your team name
    key     = "ecs/terraform.tfstate" # Replace with your team name and username
    region  = "ap-northeast-1"
    profile = "default"
  }
}
