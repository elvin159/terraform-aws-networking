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
    bucket       = "example-terraform-state-prd"
    key          = "cluster1/networking/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  environment = "prd"
  account_id  = "333333333333"
  name        = "cluster1-prd"

  default_tags = {
    Cluster     = "cluster1"
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# Authentication is OIDC only, with no static access keys. CI exchanges its GitHub OIDC token for
# a short-lived session in this environment's account (.github/workflows/terraform.yml).
# allowed_account_ids stops a run against the wrong account.
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias               = "us_west_1"
  region              = "us-west-1"
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = local.default_tags
  }
}

# Consumers should pin a released tag, e.g.
# source = "git::https://github.com/<org>/terraform-aws-networking.git?ref=v1.0.0"
module "networking_us_east_1" {
  source = "../../.."

  name     = local.name
  vpc_cidr = "10.32.0.0/16"
  az_count = 3
}

module "networking_us_west_1" {
  source = "../../.."

  providers = {
    aws = aws.us_west_1
  }

  name     = local.name
  vpc_cidr = "10.33.0.0/16"
  az_count = 2 # us-west-1 has only 2 AZs
}
