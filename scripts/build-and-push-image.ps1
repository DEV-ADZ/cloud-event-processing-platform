# This script builds a Docker image for the application and pushes it to Amazon ECR.

param(
    [string]$Region = "eu-west-1",
    [string]$AccountId = "596517178555",
    [string]$RepositoryName = "cloud-event-processing-platform-dev-api",
    [string]$ImageTag = "dev",
    [string]$DockerContextPath = "$PSScriptRoot\..\events-api"
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
Require-Command docker

$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$FullImageName = "$Registry/$RepositoryName`:$ImageTag"

Write-Host "Logging out of ECR registry first..." -ForegroundColor Cyan
docker logout $Registry 2>$null | Out-Null

Write-Host "Logging in to Amazon ECR..." -ForegroundColor Cyan
cmd.exe /c "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry"
if ($LASTEXITCODE -ne 0) {
    throw "Docker login to ECR failed."
}

Write-Host "Building Docker image locally..." -ForegroundColor Cyan
docker build -t "${RepositoryName}:${ImageTag}" $DockerContextPath
if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed."
}

Write-Host "Tagging image for ECR..." -ForegroundColor Cyan
docker tag "${RepositoryName}:${ImageTag}" $FullImageName
if ($LASTEXITCODE -ne 0) {
    throw "Docker tag failed."
}

Write-Host "Pushing image to ECR..." -ForegroundColor Cyan
docker push $FullImageName
if ($LASTEXITCODE -ne 0) {
    throw "Docker push failed."
}

Write-Host "Verifying image exists in ECR..." -ForegroundColor Cyan
aws ecr describe-images `
    --repository-name $RepositoryName `
    --region $Region `
    --image-ids imageTag=$ImageTag | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Image verification in ECR failed."
}

Write-Host "Image push complete: $FullImageName" -ForegroundColor Green