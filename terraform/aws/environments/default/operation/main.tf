module "operation" {
  source = "../../../modules/operation"

  prefix    = "handson"
  vpc_id    = data.terraform_remote_state.network.outputs.vpc_id
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_ids[0]

  instance_type    = "t3.micro"
  root_volume_size = 20

  # データベースシークレットのARNを設定
  db_secret_arn = data.terraform_remote_state.database.outputs.secret_arn

  tags = var.default_tags
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "myproject-terraform-state"                # Replace with your team name
    key    = "network/terraform.tfstate" # Replace with your team name
    region = "ap-northeast-1"
    profile = "default"
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = "myproject-terraform-state"                 # Replace with your team name
    key    = "database/terraform.tfstate" # Replace with your team name
    region = "ap-northeast-1"
    profile = "default"
  }
}
