output "vpc_ids" {
  description = "VPC ID, by region."
  value = {
    "us-east-1" = module.networking_us_east_1.vpc_id
  }
}

output "public_subnet_ids" {
  description = "Public subnet IDs (internet-facing ALBs), by region."
  value = {
    "us-east-1" = module.networking_us_east_1.public_subnet_ids
  }
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes, internal ALBs), by region."
  value = {
    "us-east-1" = module.networking_us_east_1.private_subnet_ids
  }
}

output "nat_public_ips" {
  description = "NAT gateway public IPs, by region."
  value = {
    "us-east-1" = module.networking_us_east_1.nat_public_ips
  }
}
