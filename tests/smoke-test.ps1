#Requires -Version 5.1
<#
.SYNOPSIS
  Tests de fumee : disponibilite, code HTTP, contenu, endpoint /health.
.PARAMETER Url
  URL de base a tester. Si vide, lit la sortie 'url' de Terraform.
#>

param(
  [string]$Url = ""
)

$ErrorActionPreference = "Stop"

if (-not $Url) {
  Push-Location "$PSScriptRoot\..\terraform"
  try {
    $Url = (terraform output -raw url).Trim()
  } finally {
    Pop-Location
  }
}

Write-Host "==> Cible : $Url" -ForegroundColor Cyan

$failures = 0

function Test-Step {
  param([string]$Name, [scriptblock]$Block)
  Write-Host "  [TEST] $Name" -NoNewline
  try {
    & $Block
    Write-Host "  OK" -ForegroundColor Green
  } catch {
    Write-Host "  ECHEC : $($_.Exception.Message)" -ForegroundColor Red
    $script:failures++
  }
}

# 1. Disponibilite (avec retry car cloud-init prend ~60s apres apply)
Test-Step "Disponibilite HTTP (avec retry 60s)" {
  $deadline = (Get-Date).AddSeconds(120)
  $ok = $false
  while ((Get-Date) -lt $deadline) {
    try {
      $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
      if ($r.StatusCode -eq 200) { $ok = $true; break }
    } catch {}
    Start-Sleep -Seconds 5
  }
  if (-not $ok) { throw "Site injoignable apres 120s" }
}

# 2. Code HTTP 200
Test-Step "Code HTTP 200 sur /" {
  $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
  if ($r.StatusCode -ne 200) { throw "Code recu: $($r.StatusCode)" }
}

# 3. Contenu attendu
Test-Step "Contenu HTML attendu" {
  $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
  if ($r.Content -notmatch "Projet d'etude") {
    throw "Contenu attendu absent de la page"
  }
}

# 4. Header Server = nginx
Test-Step "Header 'Server: nginx'" {
  $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
  if ($r.Headers.Server -notmatch "nginx") {
    throw "Header Server inattendu: $($r.Headers.Server)"
  }
}

# 5. Endpoint /health
Test-Step "Endpoint /health renvoie 'ok'" {
  $r = Invoke-WebRequest -Uri "$Url/health" -UseBasicParsing -TimeoutSec 10
  if ($r.Content.Trim() -ne "ok") { throw "Reponse inattendue: $($r.Content)" }
}

# 6. 404 sur route inexistante
Test-Step "Route inexistante renvoie 404" {
  try {
    Invoke-WebRequest -Uri "$Url/page-qui-nexiste-pas" -UseBasicParsing -TimeoutSec 10 | Out-Null
    throw "Aucune erreur levee"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404) {
      throw "Code recu: $($_.Exception.Response.StatusCode.value__)"
    }
  }
}

Write-Host ""
if ($failures -eq 0) {
  Write-Host "Tous les tests de fumee sont passes." -ForegroundColor Green
  exit 0
} else {
  Write-Host "$failures test(s) en echec." -ForegroundColor Red
  exit 1
}
