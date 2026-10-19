# AWS Terraform Handson

Go で書かれた書籍管理 API を AWS 上にデプロイするハンズオンです。
Terraform を使って VPC / ECS Fargate / Aurora MySQL / CloudFront を構築します。

## Architecture

```
CloudFront (HTTPS) → ALB (HTTP) → ECS Fargate (ARM64) → Aurora MySQL
```

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (v2)
- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.10.0)
- [Docker](https://docs.docker.com/get-docker/)
- AWS account with appropriate permissions
- S3 bucket for Terraform state (e.g., `yourname-handson-terraform-state`)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/CyberAgentHack/aws-terraform-handson.git
cd aws-terraform-handson

make setup BUCKET_PREFIX=yourname-handson USER_NAME=yourname
git diff  # Verify changes
```

### 2. Build and Deploy

```bash
# Infrastructure (apply in order)
make network
make ecr
make database
make operation

# Build and push container image
make docker-build
make ecr-login
make docker-tag
make docker-push

# Deploy application
make ecs
make db-setup
make cloudfront
```

### 3. Access the Application

```bash
# Get CloudFront URL
cd terraform/aws/environments/default/cloudfront
terraform output app_url
# => https://xxxxxx.cloudfront.net

# Test API
curl https://xxxxxx.cloudfront.net/api/v1/books
curl -X POST https://xxxxxx.cloudfront.net/api/v1/books \
  -H "Content-Type: application/json" \
  -d '{"title":"The Go Programming Language","author":"Donovan & Kernighan"}'
```

### 4. Cleanup

```bash
make destroy-all
```

## Project Structure

```
.
├── api/                              # Go application
│   ├── Dockerfile
│   └── ...
├── db/
│   └── migrations/                   # SQL migrations
├── terraform/aws/
│   ├── environments/default/          # Environment config
│   │   ├── network/                  # VPC, Subnets, NAT Gateway
│   │   ├── ecr/                      # ECR Repository
│   │   ├── database/                 # Aurora MySQL
│   │   ├── operation/                # Operation EC2 (for DB setup)
│   │   ├── ecs/                      # ECS Fargate + ALB
│   │   └── cloudfront/               # CloudFront distribution
│   └── modules/                      # Reusable Terraform modules
│       ├── network/
│       ├── ecr/
│       ├── database/
│       ├── operation/
│       ├── ecs/
│       └── cloudfront/
├── Makefile
└── README.md
```

## Module Dependency

```
network → database → operation → ecr → ecs → cloudfront
```

## Make Commands

| Command | Description |
|---------|-------------|
| `make setup` | Initialize project with your settings |
| `make network` | Deploy VPC, Subnets, NAT Gateway |
| `make ecr` | Deploy ECR Repository |
| `make database` | Deploy Aurora MySQL |
| `make operation` | Deploy Operation EC2 |
| `make ecs` | Deploy ECS Fargate + ALB |
| `make cloudfront` | Deploy CloudFront distribution |
| `make docker-build` | Build container image |
| `make ecr-login` | Login to ECR |
| `make docker-tag` | Tag image for ECR |
| `make docker-push` | Push image to ECR |
| `make db-setup` | Create DB user and tables |
| `make destroy-all` | Destroy all resources |
| `make help` | Show all commands |
