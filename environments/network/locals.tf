locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}