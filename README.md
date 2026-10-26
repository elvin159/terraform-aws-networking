# terraform-aws-networking

Creates one Multi-AZ VPC for EKS in one region:

- **Private subnets** (one `/18` per AZ) for nodes and pods, tagged `kubernetes.io/role/internal-elb=1`.
- **Public subnets** (one `/24` per AZ) for internet-facing load balancers, tagged `kubernetes.io/role/elb=1`.
- Internet gateway, NAT gateways (one per AZ), and route tables.
- S3 gateway endpoint (free; ECR image pulls skip NAT charges).
- VPC flow logs to CloudWatch Logs.
- Default security group with all rules removed.

The AWS Load Balancer Controller finds the subnets through these tags, so you don't list subnet IDs in Ingress or Service objects.

## Environments

There is one AWS account per environment and one VPC per region. Each environment is one Terraform root with one state file, and it calls the module once per region.

| Environment | Region | VPC CIDR | AZs | NAT gateways |
|---|---|---|---|---|
| dev | us-east-1 | `10.0.0.0/16` | 3 | 1 (saves cost) |
| stg | us-east-1 | `10.16.0.0/16` | 3 | 3 |
| stg | us-west-1 | `10.17.0.0/16` | 2 | 2 |
| prd | us-east-1 | `10.32.0.0/16` | 3 | 3 |
| prd | us-west-1 | `10.33.0.0/16` | 2 | 2 |

stg and prd are configured the same way. They differ only in account and CIDR. us-west-1 has only 2 AZs, so it uses 2 in both environments.

The CIDRs don't overlap, so you can later connect any two VPCs with peering or a Transit Gateway. Leave room for each new region or environment: `10.48.0.0/16` and up are free.

### Address plan for each /16

| Range | Use | Usable IPs |
|---|---|---|
| `x.x.0.0/18`, `x.x.64.0/18`, `x.x.128.0/18` | Private, one per AZ | 16,379 each |
| `x.x.192.0/24`, `x.x.193.0/24`, `x.x.194.0/24` | Public, one per AZ | 251 each |
| `x.x.195.0` to `x.x.255.255` | Unallocated, for future subnets | |

The VPC CNI gives every pod a VPC IP, so most of the space goes to the private subnets. Each AZ has a fixed slot, so going from 2 to 3 AZs never renumbers an existing subnet.

## Usage

```hcl
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["222222222222"]
}

provider "aws" {
  alias               = "us_west_1"
  region              = "us-west-1"
  allowed_account_ids = ["222222222222"]
}

module "networking_us_east_1" {
  source = "git::https://github.com/<org>/terraform-aws-networking.git?ref=v1.0.0"

  name     = "cluster1-stg"
  vpc_cidr = "10.16.0.0/16"
  az_count = 3
}

module "networking_us_west_1" {
  source    = "git::https://github.com/<org>/terraform-aws-networking.git?ref=v1.0.0"
  providers = { aws = aws.us_west_1 }

  name     = "cluster1-stg"
  vpc_cidr = "10.17.0.0/16"
  az_count = 2
}
```

The module takes its region from the provider you pass it. For dev, add `single_nat_gateway = true`. For us-west-1, set `az_count = 2`.

Pass `private_subnet_ids` from each module call to the EKS cluster and node groups in that region.

### Settings

| Setting | Default | Description |
|---|---|---|
| `name` | required | Name prefix, usually `<cluster>-<environment>`, e.g. `cluster1-stg`. |
| `vpc_cidr` | required | RFC1918 `/16`. Must be unique across all environments and regions. |
| `az_count` | `3` | `2` or `3`. |
| `single_nat_gateway` | `false` | One NAT gateway for all AZs. Dev only: one AZ outage would take out egress. |
| `flow_log_retention_days` | `90` | How long CloudWatch Logs keeps flow logs. |
| `public_subnet_tags` / `private_subnet_tags` | `{}` | Extra subnet tags, e.g. `karpenter.sh/discovery`. |
| `tags` | `{}` | Tags on every resource. |

### Outputs

`vpc_id`, `vpc_cidr_block`, `azs`, `public_subnet_ids`, `private_subnet_ids`, `private_route_table_ids`, `nat_public_ips`. The subnet lists are in the same order as `azs`.

## The root configurations

[`examples/cluster1`](examples/cluster1) is what CI deploys. It shows the layout of a repo for one Kubernetes cluster: one folder per environment, and each folder is its own Terraform root.

```
examples/cluster1/
├── dev/
│   ├── main.tf              # backend, provider, environment values, module call for us-east-1
│   ├── outputs.tf
│   └── .terraform.lock.hcl
├── stg/
│   ├── main.tf              # backend, providers, environment values, module calls for us-east-1 and us-west-1
│   ├── outputs.tf
│   └── .terraform.lock.hcl
└── prd/
    ├── main.tf              # same as stg, with the prd account, state bucket and CIDRs
    ├── outputs.tf
    └── .terraform.lock.hcl
```

Each `main.tf` contains everything for its environment: the state bucket, the account ID, a provider per region, and a `networking_<region>` module call per region. There are no tfvars or backend files. Outputs are maps keyed by region, e.g. `private_subnet_ids["us-west-1"]`.

`allowed_account_ids` stops Terraform from running if your credentials belong to a different account than the folder is for.

### Making a change

1. Edit the module, or `examples/cluster1/<env>/main.tf` for the environment you're changing.
2. Open a PR. Review the `plan` job summary for each environment.
3. Get approval and merge. `apply` runs dev, then stg, then prd.

To add a region to an environment, add a provider with an `alias` and a `networking_<region>` module call to that environment's `main.tf`, and add the region to its `outputs.tf`. Pick an unused `/16` (see [Environments](#environments)).

### Running a plan locally

Use SSO or another short-lived credential, never access keys:

```sh
cd examples/cluster1/stg
aws sso login --profile stg
export AWS_PROFILE=stg

terraform init
terraform plan -lock=false
```

Leave applies to CI.

## CI/CD

[`.github/workflows/terraform.yml`](.github/workflows/terraform.yml):

| Event | Runs |
|---|---|
| PR into `main` opened, reopened or updated with new commits | `fmt`, `validate` (with tests), then `plan` for every environment |
| Merge into `main` | `fmt`, `validate`, then `apply` one environment at a time: dev, stg, prd. Stops at the first failure. |

GitHub logs in to AWS through OIDC; the repo holds no AWS secrets. PR plans skip the state lock so they never block an apply. At merge time, apply creates a new plan rather than reusing the PR's.

### One-time setup

1. **Branch protection on `main`:** require an approved PR, and require the `fmt`, `validate` and `plan` checks to pass. This is what limits applies to approved changes.
2. **GitHub environments:** each needs the variable `AWS_ROLE_ARN`. Regions are set in each root's provider blocks.
   - `dev-plan`, `stg-plan`, `prd-plan`: unprotected, holding a read-only plan role.
   - `dev`, `stg`, `prd`: limited to the `main` branch, holding the apply role. Add required reviewers (at least on `prd`) if you want a manual sign-off before apply.
3. **In each AWS account:** register the IAM OIDC provider `token.actions.githubusercontent.com` (audience `sts.amazonaws.com`). Create two roles, each trusting a single GitHub environment through the `sub` claim:
   - Plan role: `repo:<org>/<repo>:environment:<env>-plan`. Read-only access plus the state bucket.
   - Apply role: `repo:<org>/<repo>:environment:<env>`. EC2/VPC, CloudWatch Logs and IAM (for the flow log role) write access, plus the state bucket.

## Versions

| | Module | Root configurations (`examples/cluster1/<env>`) |
|---|---|---|
| Terraform | `>= 1.9.0, < 2.0.0` | `1.17.0` |
| AWS provider | `>= 6.0.0, < 7.0.0` | `6.70.0`, locked in each folder's `.terraform.lock.hcl` |

Pin the module by git tag (`?ref=vX.Y.Z`).

## Testing

Offline tests need no AWS access:

```sh
terraform init -backend=false
terraform test
```

## Not included

The EKS cluster, Transit Gateway or peering, interface VPC endpoints, the CI roles and the GitHub OIDC provider are managed elsewhere. IRSA roles are in `terraform-aws-identity`.
