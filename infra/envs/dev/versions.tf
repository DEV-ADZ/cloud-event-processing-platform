terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "cloud-event-processing-platform-bootstrap-tf-state-adilr-2026"
    key          = "envs/dev/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}