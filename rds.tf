locals {
  name   = "web-mariadb"
  region = var.region

  #  vpc_cidr = var.vpc_cidr
  #  azs      = module.vpc.azs

  engine                = "mariadb"
  engine_version        = "10.11.8"
  family                = "mariadb10.11" # DB parameter group
  major_engine_version  = "10.11"        # DB option group
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  port                  = 3306
}

resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "password" {
  name = "test-mariadb-password"
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.password.id
  secret_string = random_password.master.result
}

resource "aws_iam_user" "mariadb_user" {
  name = "mariadb_user"
}

################################################################################
# Master DB
################################################################################

module "rds-master" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = "${local.name}-master"

  engine               = local.engine
  engine_version       = local.engine_version
  family               = local.family
  major_engine_version = local.major_engine_version
  instance_class       = local.instance_class

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage

  db_name  = "webdb"
  username = "mariadb_user"
  password = aws_secretsmanager_secret_version.password.secret_string
  # Not supported with replicas
  manage_master_user_password = false
  port                        = local.port

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.mariadb_subnet_group.name
  vpc_security_group_ids = [module.security_group_mariadb.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]

  # Backups are required in order to create a replica
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = local.common_tags
}

################################################################################
# Replica DB
################################################################################

module "rds-replica" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = "${local.name}-replica"

  # Source database. For cross-region use db_instance_arn
  replicate_source_db = module.rds-master.db_instance_identifier

  engine               = local.engine
  engine_version       = local.engine_version
  family               = local.family
  major_engine_version = local.major_engine_version
  instance_class       = local.instance_class

  # Replica inherits the primary's allocated_storage 
  #allocated_storage     = local.allocated_storage
  #max_allocated_storage = local.max_allocated_storage

  port = local.port

  password = aws_secretsmanager_secret_version.password.secret_string
  # Not supported with replicas
  manage_master_user_password = false

  multi_az               = false
  vpc_security_group_ids = [module.security_group_mariadb.security_group_id]

  maintenance_window              = "Tue:00:00-Tue:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = local.common_tags
}

resource "aws_iam_policy" "mariadb_policy" {
  name        = "mariadb_policy"
  description = "Policy for MariaDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["rds:AmazonRDSFullAccess"]
        Effect   = "Allow"
        Resource = ["*"]
      }
    ]
  })
}

# To be used for the EC2 instance profile to access MariaDB
resource "aws_iam_role" "mariadb_role" {
  name = "mariadb_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "mariadb_user_policy_attachment" {
  user       = aws_iam_user.mariadb_user.name
  policy_arn = aws_iam_policy.mariadb_policy.arn
}

module "security_group_mariadb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-sg"
  description = "MariaDB security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_source_security_group_id = [
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      description              = "Rule for MariaDB access"
      source_security_group_id = aws_security_group.ec2_web_mariadb_sg.id
    }
  ]

  tags = local.common_tags
}
