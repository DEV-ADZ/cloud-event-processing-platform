# This script handles cluster setup by:
# - Checking for required tools (AWS CLI, kubectl, Helm)
# - Reconnecting kubectl to the EKS cluster
# - Ensuring the namespace exists
# - Installing/upgrading the AWS Load Balancer Controller
# - Installing/upgrading Metrics Server
# - Installing/upgrading kube-prometheus-stack

param(
    [string]$ClusterName = "cloud-event-processing-platform-dev-eks",
    [string]$Region = "eu-west-1",
    [string]$Namespace = "events",
    [string]$AlbControllerRoleArn = "",
    [string]$EbsCsiRoleArn = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it first and try again."
    }
}

Write-Host "Checking required tools..." -ForegroundColor Cyan
Require-Command aws
Require-Command kubectl
Require-Command helm

Write-Host "Checking EKS cluster status..." -ForegroundColor Cyan
$ClusterStatus = aws eks describe-cluster `
    --name $ClusterName `
    --region $Region `
    --query "cluster.status" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query EKS cluster status."
}

if ($ClusterStatus -ne "ACTIVE") {
    throw "Cluster '$ClusterName' is not ACTIVE. Current status: $ClusterStatus"
}

Write-Host "Updating kubeconfig for cluster access..." -ForegroundColor Cyan
aws eks update-kubeconfig `
    --region $Region `
    --name $ClusterName | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to update kubeconfig."
}
if ($EbsCsiRoleArn -ne "") {
    Write-Host "Checking Amazon EBS CSI driver add-on state..." -ForegroundColor Cyan

    $addonExists = $false
    $addonStatus = $null

    try {
        $addonStatus = aws eks describe-addon `
            --cluster-name $ClusterName `
            --region $Region `
            --addon-name aws-ebs-csi-driver `
            --query "addon.status" `
            --output text 2>$null

        if ($LASTEXITCODE -eq 0 -and $addonStatus) {
            $addonExists = $true
            Write-Host "EBS CSI add-on already exists. Current status: $addonStatus" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "EBS CSI add-on does not exist yet. It will be created." -ForegroundColor Yellow
        $addonExists = $false
    }

    if (-not $addonExists) {
        Write-Host "Creating Amazon EBS CSI driver add-on..." -ForegroundColor Cyan

        aws eks create-addon `
            --cluster-name $ClusterName `
            --region $Region `
            --addon-name aws-ebs-csi-driver `
            --service-account-role-arn $EbsCsiRoleArn `
            --resolve-conflicts OVERWRITE | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create EBS CSI add-on."
        }
    }
    else {
        Write-Host "Updating Amazon EBS CSI driver add-on..." -ForegroundColor Cyan

        aws eks update-addon `
            --cluster-name $ClusterName `
            --region $Region `
            --addon-name aws-ebs-csi-driver `
            --service-account-role-arn $EbsCsiRoleArn `
            --resolve-conflicts OVERWRITE | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update EBS CSI add-on."
        }
    }

    Write-Host "Waiting for EBS CSI add-on to become ACTIVE..." -ForegroundColor Cyan

    $maxAttempts = 30
    $attempt = 0
    $AddonStatus = ""

    do {
        Start-Sleep -Seconds 10
        $attempt++

        try {
            $AddonStatus = aws eks describe-addon `
                --cluster-name $ClusterName `
                --region $Region `
                --addon-name aws-ebs-csi-driver `
                --query "addon.status" `
                --output text
        }
        catch {
            throw "Failed to check EBS CSI add-on status."
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to check EBS CSI add-on status."
        }

        Write-Host "EBS CSI add-on status: $AddonStatus"

        if ($AddonStatus -eq "ACTIVE") {
            break
        }

        if ($AddonStatus -eq "CREATE_FAILED" -or $AddonStatus -eq "DEGRADED") {
            throw "EBS CSI add-on entered bad state: $AddonStatus"
        }

    } while ($attempt -lt $maxAttempts)

    if ($AddonStatus -ne "ACTIVE") {
        throw "Timed out waiting for EBS CSI add-on to become ACTIVE after $maxAttempts attempts."
    }
}
else {
    Write-Warning "EbsCsiRoleArn was blank, so EBS CSI driver installation was skipped."
}

Write-Host "Applying EBS CSI StorageClass..." -ForegroundColor Cyan
kubectl apply -f "$PSScriptRoot\..\k8s\storageclass-ebs.yaml"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply EBS CSI StorageClass."
}

Write-Host "Ensuring namespace '$Namespace' exists..." -ForegroundColor Cyan

@"
apiVersion: v1
kind: Namespace
metadata:
  name: $Namespace
"@ | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create or update namespace '$Namespace'."
}

kubectl get namespace $Namespace | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Namespace '$Namespace' was not created successfully."
}

Write-Host "Setting current kubectl namespace to $Namespace..." -ForegroundColor Cyan
kubectl config set-context --current --namespace=$Namespace | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to set current kubectl namespace to '$Namespace'."
}

Write-Host "Fetching VPC ID from EKS..." -ForegroundColor Cyan
$VpcId = aws eks describe-cluster `
    --name $ClusterName `
    --region $Region `
    --query "cluster.resourcesVpcConfig.vpcId" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch VPC ID from EKS."
}

Write-Host "Adding/updating Helm repos..." -ForegroundColor Cyan
helm repo add eks https://aws.github.io/eks-charts --force-update | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add/update eks Helm repo."
}

helm repo add bitnami https://charts.bitnami.com/bitnami --force-update | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add/update bitnami Helm repo."
}

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add/update prometheus-community Helm repo."
}

helm repo update | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update Helm repos."
}

if ($AlbControllerRoleArn -ne "") {
    Write-Host "Installing/upgrading AWS Load Balancer Controller..." -ForegroundColor Cyan

    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
        --namespace kube-system `
        --set clusterName=$ClusterName `
        --set region=$Region `
        --set vpcId=$VpcId `
        --set serviceAccount.create=true `
        --set serviceAccount.name=aws-load-balancer-controller `
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$AlbControllerRoleArn

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install or upgrade AWS Load Balancer Controller."
    }

    Write-Host "Waiting for AWS Load Balancer Controller rollout..." -ForegroundColor Cyan
    kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        throw "AWS Load Balancer Controller rollout failed."
    }
}
else {
    Write-Warning "AlbControllerRoleArn was blank, so AWS Load Balancer Controller installation was skipped."
    Write-Warning "If you need Ingress/ALB to work, rerun this script with -AlbControllerRoleArn set."
}

Write-Host "Installing/updating Metrics Server..." -ForegroundColor Cyan
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply Metrics Server."
}

Write-Host "Waiting for Metrics Server rollout..." -ForegroundColor Cyan
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "Metrics Server rollout failed."
}

Write-Host "Installing/upgrading kube-prometheus-stack..." -ForegroundColor Cyan
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
    --namespace monitoring `
    --create-namespace

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install or upgrade kube-prometheus-stack."
}

Write-Host "Waiting for Prometheus Operator CRDs to become available..." -ForegroundColor Cyan
Start-Sleep -Seconds 20

Write-Host "Checking CRDs..." -ForegroundColor Cyan
kubectl get crd servicemonitors.monitoring.coreos.com | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "ServiceMonitor CRD not found."
}

kubectl get crd prometheusrules.monitoring.coreos.com | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "PrometheusRule CRD not found."
}

Write-Host "Bootstrap complete. Current cluster state:" -ForegroundColor Green
kubectl get nodes
kubectl get pods -n kube-system
kubectl get pods -n monitoring