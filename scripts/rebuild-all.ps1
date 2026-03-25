# This script orchestrates the entire rebuild process by:
# - Bootstrapping the cluster (setting up namespace, controllers, etc.)
# - Building and pushing the application image
# - Deploying the application

param(
    [string]$ClusterName = "cloud-event-processing-platform-dev-eks",
    [string]$Region = "eu-west-1",
    [string]$Namespace = "events",
    [string]$AlbControllerRoleArn = "",
    [string]$AccountId = "596517178555",
    [string]$RepositoryName = "cloud-event-processing-platform-dev-api",
    [string]$ImageTag = "dev",
    [string]$EbsCsiRoleArn = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "Starting cluster bootstrap..." -ForegroundColor Cyan
& "$PSScriptRoot\bootstrap-cluster.ps1" `
    -ClusterName $ClusterName `
    -Region $Region `
    -Namespace $Namespace `
    -AlbControllerRoleArn $AlbControllerRoleArn `
    -EbsCsiRoleArn $EbsCsiRoleArn

if ($LASTEXITCODE -ne 0) {
    throw "Cluster bootstrap failed."
}

Write-Host "Building and pushing application image..." -ForegroundColor Cyan
& "$PSScriptRoot\build-and-push-image.ps1" `
    -Region $Region `
    -AccountId $AccountId `
    -RepositoryName $RepositoryName `
    -ImageTag $ImageTag

if ($LASTEXITCODE -ne 0) {
    throw "Image build/push failed."
}

Write-Host "Starting app deployment..." -ForegroundColor Cyan
& "$PSScriptRoot\deploy-app.ps1" `
    -Namespace $Namespace

if ($LASTEXITCODE -ne 0) {
    throw "Application deployment failed."
}

Write-Host "Rebuild complete." -ForegroundColor Green