output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones used, in the same order as the subnet ID lists."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per AZ. Tagged kubernetes.io/role/elb=1."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per AZ. Tagged kubernetes.io/role/internal-elb=1. Use these for EKS nodes."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "private_route_table_ids" {
  description = "Private route table IDs, one per AZ."
  value       = [for az in local.azs : aws_route_table.private[az].id]
}

output "nat_public_ips" {
  description = "NAT gateway public IPs. Outbound traffic from private subnets comes from these, for allow-listing."
  value       = [for az in local.nat_azs : aws_eip.nat[az].public_ip]
}
