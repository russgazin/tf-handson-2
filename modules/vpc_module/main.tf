resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = var.vpc_tag 
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_tag}_igw"
  }
}