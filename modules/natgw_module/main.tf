resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "${var.natgw_tag}_eip"
  }
}

resource "aws_nat_gateway" "natgw" {
 subnet_id = var.subnet_id
 allocation_id = aws_eip.eip.id

 tags = {
    Name = var.natgw_tag
 }
}