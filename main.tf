# root main.tf

module "prod_vpc" {
  source = "./modules/vpc_module"

  cidr_block = "10.0.0.0/24"
  vpc_tag    = "prod_vpc"
}

module "public_1a" {
  source = "./modules/subnet_module"

  vpc_id                  = module.prod_vpc.vpc_id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.0.0/26"
  subnet_tag              = "public_1a"
}

module "public_1b" {
  source = "./modules/subnet_module"

  vpc_id                  = module.prod_vpc.vpc_id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.0.64/26"
  subnet_tag              = "public_1b"
}

module "private_1a" {
  source = "./modules/subnet_module"

  vpc_id                  = module.prod_vpc.vpc_id
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.0.128/26"
  subnet_tag              = "private_1a"
}

module "private_1b" {
  source = "./modules/subnet_module"

  vpc_id                  = module.prod_vpc.vpc_id
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.0.192/26"
  subnet_tag              = "private_1b"
}

module "natgw" {
  source = "./modules/natgw_module"

  subnet_id = module.public_1a.id
  natgw_tag = "prod_natgw"
}

module "public_rtb" {
  source  = "./modules/rtb_module"
  vpc_id  = module.prod_vpc.vpc_id
  rtb_tag = "public_rtb"
}

resource "aws_route" "public_rtb_to_www" {
  route_table_id         = module.public_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.prod_vpc.igw_id
}

resource "aws_route_table_association" "public_rtb_to_public_1a_assoc" {
  subnet_id      = module.public_1a.id
  route_table_id = module.public_rtb.id
}

resource "aws_route_table_association" "public_rtb_to_public_1b_assoc" {
  subnet_id      = module.public_1b.id
  route_table_id = module.public_rtb.id
}

module "private_rtb" {
  source  = "./modules/rtb_module"
  vpc_id  = module.prod_vpc.vpc_id
  rtb_tag = "private_rtb"
}

resource "aws_route" "private_rtb_to_www" {
  route_table_id         = module.private_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.natgw.id
}

resource "aws_route_table_association" "private_rtb_to_private_1a_assoc" {
  subnet_id      = module.private_1a.id
  route_table_id = module.private_rtb.id
}

resource "aws_route_table_association" "private_rtb_to_private_1b_assoc" {
  subnet_id      = module.private_1b.id
  route_table_id = module.private_rtb.id
}

module "ec2_sgrp" {
  source = "./modules/sg_module"

  name        = "ec2_sgrp"
  description = "EC2 Security Group"
  vpc_id      = module.prod_vpc.vpc_id
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.ec2_sgrp.id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.ec2_sgrp.id
}

resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.ec2_sgrp.id
}

data "aws_ami" "al2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}

data "aws_key_pair" "my_key" {
  key_name = "virginia"
}

module "public_1a_instance" {
  source = "./modules/ec2_module"

  ami                    = data.aws_ami.al2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.ec2_sgrp.id]
  key_name               = data.aws_key_pair.my_key.key_name
  subnet_id              = module.public_1a.id

  user_data = <<EOT
  #!/bin/bash
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<h1>Hello, this is $(hostname -f)</h1>" > /var/www/html/index.html
  EOT

  instance_tag = "public_1a_isntance"
}

module "public_1b_instance" {
  source = "./modules/ec2_module"

  ami                    = data.aws_ami.al2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.ec2_sgrp.id]
  key_name               = data.aws_key_pair.my_key.key_name
  subnet_id              = module.public_1b.id

  user_data = <<EOT
  #!/bin/bash
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<h1>Hello, this is $(hostname -f)</h1>" > /var/www/html/index.html
  EOT

  instance_tag = "public_1b_isntance"
}

module "tg" {
  source = "./modules/tg_module"

  name     = "ec2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.prod_vpc.vpc_id
  tg_tag   = "ec2_tg"
}

resource "aws_lb_target_group_attachment" "public_1a_instance_tg_attachment" {
  target_group_arn = module.tg.arn
  target_id        = module.public_1a_instance.id
}

resource "aws_lb_target_group_attachment" "public_1b_instance_tg_attachment" {
  target_group_arn = module.tg.arn
  target_id        = module.public_1b_instance.id
}

module "alb_sgrp" {
  source = "./modules/sg_module"

  name        = "alb_sgrp"
  description = "ALB Security Group"
  vpc_id      = module.prod_vpc.vpc_id
}

resource "aws_security_group_rule" "allow_http_alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.alb_sgrp.id
}

resource "aws_security_group_rule" "allow_https_alb" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.alb_sgrp.id
}

resource "aws_security_group_rule" "allow_outbound_alb" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.alb_sgrp.id
}

data "aws_route53_zone" "selected" {
  name         = "rustemtntk.com"
  private_zone = false
}

module "cert" {
  source = "./modules/acm_module"

  domain_name               = "rustemtntk.com"
  subject_alternative_names = ["*.rustemtntk.com"]
  cert_tag                  = "prod_acm_cert"
  zone_id                   = data.aws_route53_zone.selected.zone_id
}

module "alb" {
  source = "./modules/alb_module"

  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sgrp.id]
  subnets            = [module.public_1a.id, module.public_1b.id]
  alb_tag            = "alb"
  certificate_arn    = module.cert.arn
  target_group_arn   = module.tg.arn
}

module "my_app_cname" {
  source = "./modules/route53_module"

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "handsontwo.rustemtntk.com"
  type    = "CNAME"
  ttl     = 60
  records = [module.alb.dns_name]
}