#Requires -Version 5.1
<#
.SYNOPSIS
  Provisionne le Storage Account Azure pour le backend Terraform (à executer UNE fois).
.DESCRIPTION
  Crée: resource group, storage account, container "tfstate".
  Affiche les valeurs à reporter dans backend.hcl / variables CI.
#>

param(
  [string]$Location          = "francecentral",
  [string]$ResourceGroupName = "rg-tfstate-projet-etude",
  [string]$StorageAccountName = "tfstateprojetetude$((Get-Random -Maximum 9999).ToString('0000'))",
  [string]$ContainerName     = "tfstate"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Verification de la connexion Azure CLI..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
  Write-Host "Non connecte. Lancez 'az login' d'abord." -ForegroundColor Red
  exit 1
}
Write-Host "    Subscription: $($account.name) ($($account.id))" -ForegroundColor Green

Write-Host "==> Creation du resource group $ResourceGroupName..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --output none

Write-Host "==> Creation du storage account $StorageAccountName..." -ForegroundColor Cyan
az storage account create `
  --name $StorageAccountName `
  --resource-group $ResourceGroupName `
  --location $Location `
  --sku Standard_LRS `
  --encryption-services blob `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --output none

Write-Host "==> Creation du container $ContainerName..." -ForegroundColor Cyan
az storage container create `
  --name $ContainerName `
  --account-name $StorageAccountName `
  --auth-mode login `
  --output none

Write-Host ""
Write-Host "==> Bootstrap termine !" -ForegroundColor Green
Write-Host ""
Write-Host "Reportez ces valeurs dans terraform/backend.hcl :" -ForegroundColor Yellow
Write-Host ""
Write-Host "resource_group_name  = `"$ResourceGroupName`""
Write-Host "storage_account_name = `"$StorageAccountName`""
Write-Host "container_name       = `"$ContainerName`""
Write-Host "key                  = `"projet-etude.tfstate`""
Write-Host ""
Write-Host "Et dans GitLab CI/CD > Variables (masquees) :" -ForegroundColor Yellow
Write-Host "  TF_BACKEND_RG = $ResourceGroupName"
Write-Host "  TF_BACKEND_SA = $StorageAccountName"
Write-Host "  TF_BACKEND_CONTAINER = $ContainerName"
