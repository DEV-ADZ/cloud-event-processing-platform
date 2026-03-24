output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "github_actions_ecr_push_role_arn" {
  value = aws_iam_role.github_actions_ecr_push_role.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}