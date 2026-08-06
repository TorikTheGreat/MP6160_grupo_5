param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("main_forward", "main_inverse", "isolated_forward", "isolated_inverse", "baseline_forward", "baseline_inverse")]
    [string]$Variant,
    [double[]]$PeriodsNs = @(6.0, 5.0, 4.5, 4.0, 3.5, 3.0),
    [string]$Part = "xck26-sfvc784-2LV-c",
    [string]$VivadoExe = "vivado",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configs = @{
    main_forward = @{ Top = "wht_lossless_core"; Project = "wht_main_forward"; Solution = "solution_main_forward" }
    main_inverse = @{ Top = "wht_lossless_inverse"; Project = "wht_main_inverse"; Solution = "solution_main_inverse" }
    isolated_forward = @{ Top = "wht_lossless_forward_isolated"; Project = "wht_isolated_forward"; Solution = "solution_isolated_forward" }
    isolated_inverse = @{ Top = "wht_lossless_inverse_isolated"; Project = "wht_isolated_inverse"; Solution = "solution_isolated_inverse" }
    baseline_forward = @{ Top = "wht_multiplier_forward"; Project = "wht_baseline_forward"; Solution = "solution_baseline_forward" }
    baseline_inverse = @{ Top = "wht_multiplier_inverse"; Project = "wht_baseline_inverse"; Solution = "solution_baseline_inverse" }
}
$config = $configs[$Variant]
$rtlDir = Join-Path $scriptDir "work\$Variant\hls\$($config.Project)\$($config.Solution)\syn\verilog"
$sweepDir = Join-Path $scriptDir "reports\$Variant\timing_sweep"
if (-not (Test-Path $rtlDir)) {
    throw "RTL not found: $rtlDir. First run run_variant.ps1 -Variant $Variant -Mode HlsOnly"
}
New-Item -ItemType Directory -Force -Path $sweepDir | Out-Null

$env:WHT_TOP = $config.Top
$env:WHT_RTL_DIR = $rtlDir
$env:WHT_PART = $Part

foreach ($period in $PeriodsNs) {
    $periodText = $period.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $tag = ($periodText -replace '\.', 'p') + "ns"
    $outDir = Join-Path $sweepDir $tag
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outDir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $env:WHT_REPORT_DIR = $outDir
    $env:WHT_VIVADO_CLOCK_NS = $periodText

    Write-Host "[Sweep] $Variant at $periodText ns"
    & $VivadoExe -mode batch -source (Join-Path $scriptDir "run_configurable_vivado.tcl") -notrace 2>&1 |
        Tee-Object -FilePath (Join-Path $outDir "vivado.log")
    if ($LASTEXITCODE -ne 0) { throw "Vivado failed for period $periodText ns" }
}

& $PythonExe (Join-Path $scriptDir "tools\summarize_sweep.py") `
    --sweep-dir $sweepDir --variant $Variant
if ($LASTEXITCODE -ne 0) { throw "Timing sweep summarization failed" }
