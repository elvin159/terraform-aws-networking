terraform {
  # Root configurations pin exact versions; commit .terraform.lock.hcl alongside this file.
  required_version = "1.17.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }

  # State lives in this environment's account.
  backend "s3" {
    bucket       = "example-terraform-state-dev"
    key          = "cluster1/networking/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  environment = "dev"
  account_id  = "111111111111"
  name        = "cluster1-dev"
}

# Authentication is OIDC only, with no static access keys. CI exchanges its GitHub OIDC token for
# a short-lived session in this environment's account (.github/workflows/terraform.yml).
# allowed_account_ids stops a run against the wrong account.
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = {
      Cluster     = "cluster1"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

# Consumers should pin a released tag, e.g.
# source = "git::https://github.com/<org>/terraform-aws-networking.git?ref=v1.0.0"
module "networking_us_east_1" {
  source = "../../.."

  name     = local.name
  vpc_cidr = "10.0.0.0/16"
  az_count = 3

  # Saves cost; one AZ outage takes out egress. Never set this in stg or prd.
  single_nat_gateway = true
}
