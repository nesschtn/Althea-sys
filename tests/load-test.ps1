#Requires -Version 7.0
<#
.SYNOPSIS
  Test de charge leger en pur PowerShell (sans dependance externe).
  Lance N requetes en parallele et calcule RPS, latence p50/p95/p99, taux d'erreur.
.PARAMETER Url
  URL cible. Lue depuis terraform output si vide.
.PARAMETER TotalRequests
  Nombre total de requetes a envoyer.
.PARAMETER Concurrency
  Nombre de workers paralleles.
.PARAMETER MaxErrorRate
  Seuil d'echec : si plus de X % de requetes echouent, le test echoue.
.PARAMETER MaxP95Ms
  Seuil de latence : si p95 > X ms, le test echoue (probleme de dimensionnement).
#>

param(
  [string]$Url            = "",
  [int]$TotalRequests     = 500,
  [int]$Concurrency       = 20,
  [double]$MaxErrorRate   = 1.0,
  [int]$MaxP95Ms          = 1000
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "PowerShell 7+ requis (ForEach-Object -Parallel). Installer: winget install Microsoft.PowerShell" -ForegroundColor Red
  exit 1
}

if (-not $Url) {
  Push-Location "$PSScriptRoot\..\terraform"
  try { $Url = (terraform output -raw url).Trim() } finally { Pop-Location }
}

Write-Host "==> Test de charge" -ForegroundColor Cyan
Write-Host "    URL          : $Url"
Write-Host "    Requetes     : $TotalRequests"
Write-Host "    Concurrence  : $Concurrency"
Write-Host "    Seuil erreur : $MaxErrorRate %"
Write-Host "    Seuil p95    : $MaxP95Ms ms"
Write-Host ""

$start = Get-Date

$results = 1..$TotalRequests | ForEach-Object -Parallel {
  $t0 = Get-Date
  try {
    $r = Invoke-WebRequest -Uri $using:Url -UseBasicParsing -TimeoutSec 10
    [pscustomobject]@{
      Success = ($r.StatusCode -eq 200)
      Latency = ((Get-Date) - $t0).TotalMilliseconds
      Status  = $r.StatusCode
    }
  } catch {
    [pscustomobject]@{
      Success = $false
      Latency = ((Get-Date) - $t0).TotalMilliseconds
      Status  = 0
    }
  }
} -ThrottleLimit $Concurrency

$duration = ((Get-Date) - $start).TotalSeconds
$successes = ($results | Where-Object Success).Count
$failures  = $TotalRequests - $successes
$errorRate = [math]::Round(($failures / $TotalRequests) * 100, 2)
$rps       = [math]::Round($TotalRequests / $duration, 2)

$latencies = $results | Where-Object Success | ForEach-Object Latency | Sort-Object
function Percentile([double[]]$arr, [double]$p) {
  if ($arr.Count -eq 0) { return 0 }
  $idx = [math]::Min([math]::Ceiling($arr.Count * $p / 100) - 1, $arr.Count - 1)
  if ($idx -lt 0) { $idx = 0 }
  return [math]::Round($arr[$idx], 1)
}

$p50 = Percentile $latencies 50
$p95 = Percentile $latencies 95
$p99 = Percentile $latencies 99
$avg = if ($latencies.Count) { [math]::Round(($latencies | Measure-Object -Average).Average, 1) } else { 0 }

Write-Host "==> Resultats" -ForegroundColor Cyan
Write-Host "    Duree       : $([math]::Round($duration, 2)) s"
Write-Host "    Succes      : $successes / $TotalRequests"
Write-Host "    Echecs      : $failures ($errorRate %)"
Write-Host "    RPS         : $rps req/s"
Write-Host "    Latence avg : $avg ms"
Write-Host "    Latence p50 : $p50 ms"
Write-Host "    Latence p95 : $p95 ms"
Write-Host "    Latence p99 : $p99 ms"
Write-Host ""

$failed = $false
if ($errorRate -gt $MaxErrorRate) {
  Write-Host "[KO] Taux d'erreur $errorRate% > seuil $MaxErrorRate%" -ForegroundColor Red
  $failed = $true
}
if ($p95 -gt $MaxP95Ms) {
  Write-Host "[KO] p95 $p95 ms > seuil $MaxP95Ms ms - dimensionnement insuffisant ?" -ForegroundColor Red
  $failed = $true
}

if ($failed) {
  Write-Host ""
  Write-Host "Pistes : augmenter vm_size (B1s -> B2s), verifier credits CPU burst (B-series), ajouter cache nginx." -ForegroundColor Yellow
  exit 1
}

Write-Host "Test de charge OK - dimensionnement adapte." -ForegroundColor Green
exit 0
