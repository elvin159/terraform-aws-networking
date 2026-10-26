variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "account_id" {
  description = "AWS account ID for this environment. The provider refuses to run against any other account."
  type        = string
}

variable "region" {
  description = "AWS region for this VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (RFC1918 /16), unique across all environments and regions."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "One NAT gateway for all AZs. Dev only."
  type        = bool
  default     = false
}
