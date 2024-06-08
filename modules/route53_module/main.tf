resource "aws_route53_record" "record" {
  zone_id = var.zone_id
  name    = var.name # type this in browser url bar ex: myapp.com
  type    = var.type
  ttl     = var.ttl
  records = var.records # dns query result: alb.amazon.elb.name.1238409sdaf
}
