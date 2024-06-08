terraform {
  backend "s3" {
    bucket = "rustemtentech"
    region = "us-east-1"
    key    = "handson-2-sf"
  }
}