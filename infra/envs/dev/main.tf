resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tf_sanity" {
  bucket = "${var.project}-${var.env}-tf-sanity-${random_id.suffix.hex}"
}

module "vpc" {
  source  = "../../modules/vpc"
  project = var.project
  env     = var.env
}