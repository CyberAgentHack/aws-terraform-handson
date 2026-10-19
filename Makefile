.PHONY: setup check-setup ecr-login docker-build docker-tag docker-push \
       network ecr database operation ecs cloudfront \
       db-setup destroy-cloudfront destroy-ecs destroy-ecr destroy-operation destroy-database destroy-network \
       destroy-all help

ENV_DIR       := terraform/aws/environments/default
REGION        := ap-northeast-1
ENV_FILE      := .env.handson

PROFILE       ?= default
BUCKET_PREFIX ?= myproject

# Load saved settings
-include $(ENV_FILE)
export

####################
# Setup
####################

# Example:
#   make setup BUCKET_PREFIX=yourname-handson USER_NAME=yourname
setup:
ifndef BUCKET_PREFIX
	$(error BUCKET_PREFIX is required. Example: make setup BUCKET_PREFIX=yourname-handson USER_NAME=yourname)
endif
ifndef USER_NAME
	$(error USER_NAME is required. Example: make setup BUCKET_PREFIX=yourname-handson USER_NAME=yourname)
endif
	@echo "========================================="
	@echo "  AWS Handson Setup"
	@echo "  BUCKET_PREFIX: $(BUCKET_PREFIX)"
	@echo "  USER_NAME:     $(USER_NAME)"
	@echo "  PROFILE:       $(PROFILE)"
	@echo "========================================="
	@# --- bucket prefix ---
	@find $(ENV_DIR) -type f \( -name "*.tf" -o -name "*.md" \) \
		-exec sed -i '' 's/myproject-/$(BUCKET_PREFIX)-/g' {} +
	@sed -i '' 's/myproject-/$(BUCKET_PREFIX)-/g' README.md
	@# --- profile ---
	@if [ "$(PROFILE)" != "default" ]; then \
		find $(ENV_DIR) -type f -name "*.tf" \
			-exec sed -i '' 's/profile = "default"/profile = "$(PROFILE)"/g' {} +; \
	fi
	@# --- ecs/variables.tf: set defaults ---
	@sed -i '' 's|# default     = "your-name" # Replace with your name|default     = "$(USER_NAME)"|g' \
		$(ENV_DIR)/ecs/variables.tf
	@sed -i '' 's|# default     = "v1" # Replace with your version|default     = "$(USER_NAME)"|g' \
		$(ENV_DIR)/ecs/variables.tf
	@# --- cloudfront/variables.tf: set defaults ---
	@sed -i '' 's|# default     = "your-name" # Replace with your name|default     = "$(USER_NAME)"|g' \
		$(ENV_DIR)/cloudfront/variables.tf
	@# --- Save settings ---
	@echo "BUCKET_PREFIX=$(BUCKET_PREFIX)" > $(ENV_FILE)
	@echo "USER_NAME=$(USER_NAME)" >> $(ENV_FILE)
	@echo "PROFILE=$(PROFILE)" >> $(ENV_FILE)
	@echo ""
	@echo "Setup complete!"
	@echo "Run 'git diff' to verify changes."

check-setup:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "Error: $(ENV_FILE) not found. Run 'make setup' first."; \
		exit 1; \
	fi

####################
# Terraform Apply
####################

network: check-setup
	cd $(ENV_DIR)/network && terraform init && terraform apply

ecr: check-setup
	cd $(ENV_DIR)/ecr && terraform init && terraform apply

database: check-setup
	cd $(ENV_DIR)/database && terraform init && terraform apply

operation: check-setup
	cd $(ENV_DIR)/operation && terraform init && terraform apply

ecs: check-setup
	cd $(ENV_DIR)/ecs && terraform init && terraform apply

cloudfront: check-setup
	cd $(ENV_DIR)/cloudfront && terraform init && terraform apply

####################
# ECR
####################

ecr-url: check-setup
	@cd $(ENV_DIR)/ecr && terraform output -raw repository_url

ecr-login: check-setup
	@REPO_URL=$$(cd $(ENV_DIR)/ecr && terraform output -raw repository_url) && \
		aws ecr get-login-password \
			--region $(REGION) \
			--profile $(PROFILE) \
		| docker login \
			--username AWS \
			--password-stdin \
			$$REPO_URL

####################
# Docker
####################

docker-build: check-setup
	docker build -t bookshelf:$(USER_NAME) -f api/Dockerfile .

docker-tag: check-setup
	@REPO_URL=$$(cd $(ENV_DIR)/ecr && terraform output -raw repository_url) && \
		docker tag bookshelf:$(USER_NAME) $$REPO_URL:$(USER_NAME) && \
		echo "Tagged: $$REPO_URL:$(USER_NAME)"

docker-push: check-setup
	@REPO_URL=$$(cd $(ENV_DIR)/ecr && terraform output -raw repository_url) && \
		docker push $$REPO_URL:$(USER_NAME) && \
		echo "Pushed: $$REPO_URL:$(USER_NAME)"

####################
# Database
####################

SECRET_ID := /rds/bookshelf/bookshelf-password

db-setup: check-setup
	@echo "========================================="
	@echo "  DB Setup via Operation EC2"
	@echo "========================================="
	@INSTANCE_ID=$$(cd $(ENV_DIR)/operation && terraform output -raw instance_id) && \
	echo "Instance: $$INSTANCE_ID" && \
	echo "" && \
	echo "Creating user bookshelf_w and running migration..." && \
	COMMAND_ID=$$(aws ssm send-command \
		--instance-ids "$$INSTANCE_ID" \
		--region $(REGION) \
		--document-name "AWS-RunShellScript" \
		--parameters '{"commands":["#!/bin/bash","set -e","SECRET=$$(aws secretsmanager get-secret-value --secret-id $(SECRET_ID) --region $(REGION) --query SecretString --output text)","DB_HOST=$$(echo $$SECRET | python3 -c \"import sys,json; print(json.load(sys.stdin)['"'"'host'"'"'])\" )","ADMIN_USER=$$(echo $$SECRET | python3 -c \"import sys,json; print(json.load(sys.stdin)['"'"'admin_username'"'"'])\" )","ADMIN_PASS=$$(echo $$SECRET | python3 -c \"import sys,json; print(json.load(sys.stdin)['"'"'admin_password'"'"'])\" )","APP_PASS=$$(echo $$SECRET | python3 -c \"import sys,json; print(json.load(sys.stdin)['"'"'password'"'"'])\" )","echo \"DB Host: $$DB_HOST\"","mysql -h $$DB_HOST -u $$ADMIN_USER -p\"$$ADMIN_PASS\" -e \"CREATE USER IF NOT EXISTS '"'"'bookshelf_w'"'"'@'"'"'%%'"'"' IDENTIFIED BY '"'"'$$APP_PASS'"'"'; GRANT ALL PRIVILEGES ON bookshelf.* TO '"'"'bookshelf_w'"'"'@'"'"'%%'"'"'; FLUSH PRIVILEGES;\"","echo \"User bookshelf_w created.\"","mysql -h $$DB_HOST -u bookshelf_w -p\"$$APP_PASS\" bookshelf -e \"CREATE TABLE IF NOT EXISTS books ( id BIGINT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, author VARCHAR(255) NOT NULL, isbn VARCHAR(20), publisher VARCHAR(255), description TEXT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP );\"","echo \"Table books created.\"","echo \"Done!\""]}' \
		--profile $(PROFILE) \
		--query 'Command.CommandId' \
		--output text) && \
	echo "SSM Command: $$COMMAND_ID" && \
	echo "Waiting for completion..." && \
	sleep 10 && \
	aws ssm get-command-invocation \
		--command-id "$$COMMAND_ID" \
		--instance-id "$$INSTANCE_ID" \
		--region $(REGION) \
		--profile $(PROFILE) \
		--query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
		--output json && \
	echo "" && \
	echo "DB setup complete!"

####################
# Terraform Destroy
####################

destroy-cloudfront: check-setup
	cd $(ENV_DIR)/cloudfront && terraform destroy

destroy-ecs: check-setup
	cd $(ENV_DIR)/ecs && terraform destroy

destroy-ecr: check-setup
	cd $(ENV_DIR)/ecr && terraform destroy

destroy-operation: check-setup
	cd $(ENV_DIR)/operation && terraform destroy

destroy-database: check-setup
	cd $(ENV_DIR)/database && terraform destroy

destroy-network: check-setup
	cd $(ENV_DIR)/network && terraform destroy

destroy-all: destroy-cloudfront destroy-ecs destroy-ecr destroy-operation destroy-database destroy-network
	@echo "All resources destroyed."

####################
# Help
####################

help:
	@echo ""
	@echo "AWS Terraform Handson"
	@echo ""
	@echo "  Setup:"
	@echo "    make setup BUCKET_PREFIX=yourname-handson USER_NAME=yourname [PROFILE=default]"
	@echo ""
	@echo "  Terraform (apply in order):"
	@echo "    make network      VPC, Subnet, NAT Gateway, etc."
	@echo "    make ecr          ECR Repository"
	@echo "    make database     Aurora MySQL"
	@echo "    make operation    Operation EC2 (for DB setup)"
	@echo "    make ecs          ECS Fargate + ALB"
	@echo "    make cloudfront   CloudFront distribution"
	@echo ""
	@echo "  Docker:"
	@echo "    make docker-build   Build container image"
	@echo "    make docker-tag     Tag image for ECR"
	@echo "    make docker-push    Push image to ECR"
	@echo "    make ecr-login      Login to ECR"
	@echo ""
	@echo "  Database:"
	@echo "    make db-setup       Create DB user and tables via Operation EC2"
	@echo ""
	@echo "  Destroy (reverse order):"
	@echo "    make destroy-all    Destroy all resources"
	@echo ""
