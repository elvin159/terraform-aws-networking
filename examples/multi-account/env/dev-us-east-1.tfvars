environment = "dev"
account_id  = "111111111111"
region      = "us-east-1"

vpc_cidr = "10.0.0.0/16"
az_count = 3

# Saves cost; one AZ outage takes out egress. Never set this in staging or prod.
single_nat_gateway = true
