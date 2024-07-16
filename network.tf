data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_cidr                   = var.vpc_cidr
  azs                        = slice(data.aws_availability_zones.available.names, 0, 2)
  database_subnet_group_name = "mariadb-subnet-group"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  cidr = local.vpc_cidr
  name = local.project_name
  azs  = local.azs

  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  private_subnet_names = ["private-subnet-1", "private-subnet-2"]
  public_subnet_names  = ["public-subnet-1", "public-subnet-2"]

  # Set to true if you want to provision NAT Gateways for each of your private networks
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.common_tags
}

resource "aws_db_subnet_group" "mariadb_subnet_group" {

  name        = local.database_subnet_group_name
  description = "Database subnet group for ${local.project_name}"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(
    {
      "Name" = lower(local.database_subnet_group_name)
    },
    local.common_tags
  )
}