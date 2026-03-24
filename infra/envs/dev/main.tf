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

module "ecr" {
  source       = "../../modules/ecr"
  project      = var.project
  env          = var.env
  repositories = ["api"]
}

module "iam" {
  source  = "../../modules/iam"
  project = var.project
  env     = var.env

  aws_region        = var.aws_region
  github_owner      = "DEV-ADZ"
  github_repo       = "cloud-event-processing-platform"
  github_branch     = "main"
  oidc_provider_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/9E10EF78672CDC65A96F09790DA54B82"

}


module "eks" {
  source = "../../modules/eks"

  project = var.project
  env     = var.env

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn
}