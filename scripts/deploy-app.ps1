# This script deploys the application by:
# - Installing/upgrading PostgreSQL using Helm
# - Applying Kubernetes manifests for the application components



param(
    [string]$Namespace = "events",
    [string]$PostgresReleaseName = "postgres",
    [string]$PostgresValuesFile = "$PSScriptRoot\..\helm-values\postgres-values.yaml",
    [string]$AppManifestPath = "$PSScriptRoot\..\k8s\app"
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
Require-Command kubectl
Require-Command helm

Write-Host "Checking namespace exists..." -ForegroundColor Cyan
kubectl get namespace $Namespace | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Namespace '$Namespace' does not exist. Run bootstrap-cluster.ps1 first."
}

Write-Host "Checking Prometheus CRDs exist before applying monitoring resources..." -ForegroundColor Cyan
kubectl get crd servicemonitors.monitoring.coreos.com | Out-Null
kubectl get crd prometheusrules.monitoring.coreos.com | Out-Null

Write-Host "Adding/updating Bitnami Helm repo..." -ForegroundColor Cyan
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update | Out-Null
helm repo update | Out-Null

Write-Host "Installing/upgrading PostgreSQL..." -ForegroundColor Cyan
helm upgrade --install $PostgresReleaseName bitnami/postgresql `
    --namespace $Namespace `
    -f $PostgresValuesFile

Write-Host "Waiting for PostgreSQL rollout..." -ForegroundColor Cyan
kubectl rollout status statefulset/$PostgresReleaseName-postgresql -n $Namespace --timeout=300s

Write-Host "Checking PostgreSQL PVC..." -ForegroundColor Cyan
kubectl get pvc -n $Namespace

Write-Host "Applying application manifests..." -ForegroundColor Cyan
kubectl apply -f $AppManifestPath

Write-Host "Waiting for events-api rollout..." -ForegroundColor Cyan
kubectl rollout status deployment/events-api -n $Namespace --timeout=300s

Write-Host "Current application resources:" -ForegroundColor Green
kubectl get pods -n $Namespace
kubectl get svc -n $Namespace
kubectl get ingress -n $Namespace