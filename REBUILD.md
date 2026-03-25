# Rebuild Instructions

1. From infra/envs/dev:

kubectl delete ingress -n events
terraform destroy

terraform apply

# get the ARN. from root
terraform output -raw alb_controller_role_arn
terraform output -raw ebs_csi_role_arn

2. From project root:

.\scripts\rebuild-all.ps1 `
  -AlbControllerRoleArn "<ALB_ROLE_ARN>" `
  -EbsCsiRoleArn "<EBS_CSI_ROLE_ARN>"


# Verification Instructions

# Cluster
kubectl get nodes
kubectl get pods -n kube-system

# App + DB
kubectl get pods -n events
kubectl get svc -n events
kubectl get pvc -n events
kubectl get ingress -n events

# Monitoring
kubectl get pods -n monitoring
kubectl get crd servicemonitors.monitoring.coreos.com
kubectl get crd prometheusrules.monitoring.coreos.com

# Metrics
kubectl top nodes
kubectl top pods -n events


# Test Application

kubectl get ingress -n events

# Use the ADDRESS from above:

curl http://<ALB-DNS>/health
curl http://<ALB-DNS>/events