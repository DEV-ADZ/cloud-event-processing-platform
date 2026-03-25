resource "aws_eks_cluster" "this" {
  name     = "${var.project}-${var.env}-eks"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = concat(
      var.private_subnet_ids,
      var.public_subnet_ids
    )
  }
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project}-${var.env}-nodes"
  node_role_arn   = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]
}