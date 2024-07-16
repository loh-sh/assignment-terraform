locals {
  instance_type            = "t2.micro"
  asg_launch_template_name = "asg-web"
  ec2_web_name             = "ec2-web"
  ec2_ssm_name             = "ec2-ssm"
  ec2_web_user_data        = <<-EOT
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    echo "Hello World from EC2" | sudo tee /var/www/html/index2.html
  EOT
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }
}

module "ec2_ssm" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.1"

  name                   = local.ec2_ssm_name
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.instance_type
  vpc_security_group_ids = [module.security_group_ec2_ssm.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.common_tags
}

module "security_group_ec2_ssm" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.ec2_ssm_name}-sg"
  description = "Security Group for EC2 SSM Host Egress"

  vpc_id = module.vpc.vpc_id

  egress_rules = ["https-443-tcp"]

  tags = local.common_tags
}

module "vpc_endpoints_ssm" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc.vpc_id

  endpoints = { for service in toset(["ssm", "ssmmessages", "ec2messages"]) :
    replace(service, ".", "_") =>
    {
      service             = service
      subnet_ids          = module.vpc.public_subnets
      private_dns_enabled = true
      tags                = { Name = "${local.ec2_ssm_name}-${service}" }
    }
  }

  create_security_group      = true
  security_group_name_prefix = "${local.ec2_ssm_name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from subnets"
      cidr_blocks = module.vpc.public_subnets_cidr_blocks
    }
  }

  tags = local.common_tags
}

# Create a security group for EC2 instances to allow ingress on port 80 :
resource "aws_security_group" "ec2_web_http_sg" {
  name        = "ec2_web_http_sg"
  description = "Security group for EC2 instances to allow HTTP access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create a security group for EC2 instances to allow ingress on port 22 :
resource "aws_security_group" "ec2_web_ssh_sg" {
  name        = "ec2_web_ssh_sg"
  description = "Security group for EC2 instances to allow SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    cidr_blocks = [module.vpc.vpc_cidr_block]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access from within VPC"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create a security group for EC2 instances to allow egress on port 3306 mariadb :
resource "aws_security_group" "ec2_web_mariadb_sg" {
  name        = "ec2_web_mariadb_sg"
  description = "Security group for EC2 instances to allow MariaDB access"
  vpc_id      = module.vpc.vpc_id

  egress {
    security_groups = [module.security_group_mariadb.security_group_id]
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    description     = "Rule for MariaDB access"
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "asg_web" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.7.0"

  name                = local.asg_launch_template_name
  instance_name       = local.ec2_web_name
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [module.vpc.private_subnets[1]]

  # Launch template
  launch_template_name   = local.asg_launch_template_name
  update_default_version = true
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = local.instance_type

  security_groups = [aws_security_group.ec2_web_http_sg.id,
    aws_security_group.ec2_web_ssh_sg.id,
    aws_security_group.ec2_web_mariadb_sg.id
  ]
  user_data = base64encode(local.ec2_web_user_data)

  target_group_arns = [module.nlb.target_groups["ex-target-one"]["arn"]]

  tags = local.common_tags
}

