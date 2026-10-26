# Offline tests: plan only, with dummy credentials (never real keys) and overridden AWS lookups.
# Run with: terraform init && terraform test

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_data {
  target = data.aws_region.current
  values = { region = "us-east-1" }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "111111111111" }
}

override_data {
  target = data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"] }
}

override_data {
  target = data.aws_iam_policy_document.flow_logs_assume_role
  values = { json = "{}" }
}

override_data {
  target = data.aws_iam_policy_document.flow_logs
  values = { json = "{}" }
}

variables {
  name     = "staging"
  vpc_cidr = "10.16.0.0/16"
}

run "three_az_layout" {
  command = plan

  assert {
    condition     = [for az in local.azs : aws_subnet.private[az].cidr_block] == ["10.16.0.0/18", "10.16.64.0/18", "10.16.128.0/18"]
    error_message = "Private subnets must be /18s in fixed slots."
  }

  assert {
    condition     = [for az in local.azs : aws_subnet.public[az].cidr_block] == ["10.16.192.0/24", "10.16.193.0/24", "10.16.194.0/24"]
    error_message = "Public subnets must be /24s starting at x.x.192.0."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["kubernetes.io/role/elb"] == "1"])
    error_message = "Public subnets must be tagged for internet-facing load balancers."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.tags["kubernetes.io/role/internal-elb"] == "1"])
    error_message = "Private subnets must be tagged for internal load balancers."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "There must be one NAT gateway per AZ by default."
  }
}

run "two_az_single_nat" {
  command = plan

  variables {
    az_count           = 2
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_subnet.private) == 2 && length(aws_subnet.public) == 2
    error_message = "az_count = 2 must create two subnets of each type."
  }

  assert {
    condition     = keys(aws_nat_gateway.this) == ["us-east-1a"]
    error_message = "single_nat_gateway must create exactly one NAT gateway."
  }
}

run "not_enough_azs" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["us-west-1b", "us-west-1c"] }
  }

  expect_failures = [aws_vpc.this]
}

run "rejects_public_cidr" {
  command = plan

  variables {
    vpc_cidr = "8.8.0.0/16"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_small_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.16.0.0/20"
  }

  expect_failures = [var.vpc_cidr]
}
