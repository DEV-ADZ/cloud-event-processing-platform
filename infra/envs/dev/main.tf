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

  aws_region    = var.aws_region
  github_owner  = "DEV-ADZ"
  github_repo   = "cloud-event-processing-platform"
  github_branch = "main"
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

resource "aws_iam_openid_connect_provider" "eks" {
  url = module.eks.cluster_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

data "aws_caller_identity" "current" {}

locals {
  oidc_provider_hostpath = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.project}-${var.env}-alb-controller-policy"
  policy = file("../../modules/iam/alb-controller-policy.json")
}

data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.project}-${var.env}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.project}-${var.env}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}