param(
    [ValidateSet("All", "HlsOnly", "VivadoOnly")]
    [string]$Mode = "All",
    [switch]$NoCosim,
    [double]$HlsClockNs = 4.0,
    [double]$VivadoClockNs = 10.0,
    [string]$Part = "xck26-sfvc784-2LV-c",
    [string]$VitisHlsExe = "vitis_hls",
    [string]$VivadoExe = "vivado",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$variants = @(
    "main_forward",
    "main_inverse",
    "isolated_forward",
    "isolated_inverse",
    "baseline_forward",
    "baseline_inverse"
)

foreach ($variant in $variants) {
    Write-Host "`n################################################################"
    Write-Host "Running $variant"
    Write-Host "################################################################"
    & (Join-Path $scriptDir "run_variant.ps1") `
        -Variant $variant `
        -Mode $Mode `
        -NoCosim:$NoCosim `
        -HlsClockNs $HlsClockNs `
        -VivadoClockNs $VivadoClockNs `
        -Part $Part `
        -VitisHlsExe $VitisHlsExe `
        -VivadoExe $VivadoExe `
        -PythonExe $PythonExe
}
