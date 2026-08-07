locals {
  aws_region = get_env("AWS_REGION", "us-east-1")
  account_id = run_cmd("aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "sre-tf-state-${trimspace(local.account_id)}-${local.aws_region}"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = local.aws_region
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOFP
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project           = "SRE-AWS-Lab"
      ManagedBy         = "Terragrunt"
      ProvisionerEngine = "Terraform-CLI"
      CostCenter        = "FinOps-FreeTier"
    }
  }
}
EOFP
}
