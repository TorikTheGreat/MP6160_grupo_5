param(
    [string]$VitisHlsExe = "vitis_hls"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $scriptDir
try {
    Write-Host "[HLS] Running Vitis HLS synthesis..."
    & $VitisHlsExe -f "$scriptDir\run_w2_hls.tcl"

    if ($LASTEXITCODE -ne 0) {
        throw "vitis_hls failed with exit code $LASTEXITCODE"
    }

    Write-Host "[HLS] Extracting preliminary metrics..."
    & "$scriptDir\extract_metrics.ps1"

    if ($LASTEXITCODE -ne 0) {
        throw "extract_metrics.ps1 failed with exit code $LASTEXITCODE"
    }

    Write-Host "[HLS] Done"
}
finally {
    Pop-Location
}
