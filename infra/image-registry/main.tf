provider "aws" {
  region  = var.region
}


variable "region" {}
variable "registry-name" {}

resource "aws_ecr_repository" "repository" {
  name = var.registry-name
}