param(
    [double[]]$PeriodsNs = @(6.0, 5.0, 4.5, 4.0, 3.5, 3.0),
    [string]$Part = "xck26-sfvc784-2LV-c",
    [string]$VivadoExe = "vivado",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($variant in @("isolated_forward", "baseline_forward")) {
    & (Join-Path $scriptDir "run_timing_sweep.ps1") `
        -Variant $variant -PeriodsNs $PeriodsNs -Part $Part -VivadoExe $VivadoExe -PythonExe $PythonExe
}
