locals {
  nlb_name = "public-nlb"
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type
  subnet_id     = module.vpc.private_subnets[1]
}

module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.9.0"

  name                             = local.nlb_name
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = false
  vpc_id                           = module.vpc.vpc_id
  subnets                          = [module.vpc.private_subnets[1]]

  listeners = {
    ex-one = {
      port     = 80
      protocol = "TCP"
      forward = {
        target_group_key = "ex-target-one"
      }
    }
  }

  target_groups = {
    ex-target-one = {
      name_prefix            = "t1-"
      protocol               = "TCP"
      port                   = 80
      target_type            = "instance"
      target_id              = aws_instance.this.id
      connection_termination = true
      preserve_client_ip     = true

      stickiness = {
        type = "source_ip"
      }

      tags = {
        tcp = true
      }
    }
  }

  tags = local.common_tags
}