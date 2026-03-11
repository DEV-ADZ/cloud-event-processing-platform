variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "aws_profile" {
  type    = string
  default = "tf-dev"
}

variable "project" {
  type    = string
  default = "cloud-event-processing-platform"
}

variable "env" {
  type    = string
  default = "dev"
}