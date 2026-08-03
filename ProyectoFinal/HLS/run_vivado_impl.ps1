param(
    [string]$VivadoExe = "C:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $VivadoExe)) {
    throw "Vivado executable not found: $VivadoExe"
}

Push-Location $scriptDir
try {
    Write-Host "[Vivado] Running post-HLS implementation..."
    & $VivadoExe -mode batch -source "$scriptDir\run_vivado_impl.tcl" -notrace
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado implementation failed with exit code $LASTEXITCODE"
    }

    Write-Host "[Vivado] Extracting implemented metrics..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptDir\extract_impl_metrics.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "extract_impl_metrics.ps1 failed with exit code $LASTEXITCODE"
    }

    Write-Host "[Vivado] Done"
}
finally {
    Pop-Location
}
