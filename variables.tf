variable "name" {
  description = "Name prefix for every resource, usually the environment (dev, staging, prod)."
  type        = string

  validation {
    # Longest derived name is the flow log IAM role "<name>-vpc-flow-logs-<region>"; IAM allows 64.
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.name))
    error_message = "name must be 1-30 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR. Must be an RFC1918 /16, unique across every environment and region so VPCs can be connected later."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.vpc_cidr, 0)) &&
      try(cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr, false) &&
      try(split("/", var.vpc_cidr)[1] == "16", false) &&
      can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", var.vpc_cidr))
    )
    error_message = "vpc_cidr must be an RFC1918 /16 network address, e.g. 10.16.0.0/16."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use. us-west-1 only has 2."
  type        = number
  default     = 3

  validation {
    condition     = contains([2, 3], var.az_count)
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs instead of one per AZ. Cheaper, but not highly available. Use in dev only."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Days to keep VPC flow logs in CloudWatch Logs."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a value CloudWatch Logs supports, e.g. 30, 90 or 365."
  }
}

variable "public_subnet_tags" {
  description = "Extra tags for public subnets."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for private subnets, e.g. { \"karpenter.sh/discovery\" = \"<cluster_name>\" }."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
