resource "aws_route_table" "rtb" {
  vpc_id = var.vpc_id

  tags = {
    Name = var.rtb_tag
  }
}