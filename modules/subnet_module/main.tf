resource "aws_subnet" "subnet" {
  vpc_id = var.vpc_id
  map_public_ip_on_launch = var.map_public_ip_on_launch
  availability_zone = var.availability_zone
  cidr_block = var.cidr_block

  tags = {
    Name = var.subnet_tag
  }
}