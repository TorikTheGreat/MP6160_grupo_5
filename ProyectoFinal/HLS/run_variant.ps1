param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("main_forward", "main_inverse", "isolated_forward", "isolated_inverse", "baseline_forward", "baseline_inverse")]
    [string]$Variant,

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

function Assert-Executable([string]$Executable, [string]$Label) {
    if ((Test-Path $Executable) -or (Get-Command $Executable -ErrorAction SilentlyContinue)) {
        return
    }
    throw "$Label executable not found: $Executable"
}

$configs = @{
    main_forward = @{
        Top = "wht_lossless_core"; Source = "../Source/wht_core.cpp"; Testbench = "../TB/wht_core_tb.cpp";
        Project = "wht_main_forward"; Solution = "solution_main_forward"
    }
    main_inverse = @{
        Top = "wht_lossless_inverse"; Source = "../Source/wht_core.cpp"; Testbench = "../TB/wht_core_inv_tb.cpp";
        Project = "wht_main_inverse"; Solution = "solution_main_inverse"
    }
    isolated_forward = @{
        Top = "wht_lossless_forward_isolated"; Source = "../Source/wht_core_isolated.cpp"; Testbench = "../TB/wht_core_isolated_forward_tb.cpp";
        Project = "wht_isolated_forward"; Solution = "solution_isolated_forward"
    }
    isolated_inverse = @{
        Top = "wht_lossless_inverse_isolated"; Source = "../Source/wht_core_isolated.cpp"; Testbench = "../TB/wht_core_isolated_inverse_tb.cpp";
        Project = "wht_isolated_inverse"; Solution = "solution_isolated_inverse"
    }
    baseline_forward = @{
        Top = "wht_multiplier_forward"; Source = "../Baseline/wht_multiplier_baseline.cpp"; Testbench = "../Baseline/wht_multiplier_baseline_tb.cpp";
        Project = "wht_baseline_forward"; Solution = "solution_baseline_forward"
    }
    baseline_inverse = @{
        Top = "wht_multiplier_inverse"; Source = "../Baseline/wht_multiplier_baseline.cpp"; Testbench = "../Baseline/wht_multiplier_inverse_tb.cpp";
        Project = "wht_baseline_inverse"; Solution = "solution_baseline_inverse"
    }
}

$config = $configs[$Variant]
$workRoot = Join-Path $scriptDir "work\$Variant\hls"
$reportDir = Join-Path $scriptDir "reports\$Variant"
$rtlDir = Join-Path $workRoot "$($config.Project)\$($config.Solution)\syn\verilog"
$logsDir = Join-Path $reportDir "logs"
$inputsDir = Join-Path $reportDir "inputs"
New-Item -ItemType Directory -Force -Path $logsDir, $inputsDir | Out-Null

Assert-Executable $PythonExe "Python"

$env:WHT_TOP = $config.Top
$env:WHT_SOURCE = $config.Source
$env:WHT_TB = $config.Testbench
$env:WHT_PROJECT = $config.Project
$env:WHT_SOLUTION = $config.Solution
$env:WHT_WORK_DIR = $workRoot
$env:WHT_PART = $Part
$hlsClockText = $HlsClockNs.ToString([System.Globalization.CultureInfo]::InvariantCulture)
$env:WHT_HLS_CLOCK_NS = $hlsClockText
$env:WHT_RUN_COSIM = $(if ($NoCosim) { "0" } else { "1" })

if ($Mode -ne "VivadoOnly") {
    Assert-Executable $VitisHlsExe "Vitis HLS"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $workRoot
    foreach ($name in @("hls", "simulation", "post_route")) {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $reportDir $name)
    }
    foreach ($name in @("manifest.json", "metrics.json", "metrics.md")) {
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $reportDir $name)
    }
    New-Item -ItemType Directory -Force -Path $workRoot, $logsDir, $inputsDir | Out-Null

    Copy-Item -Force (Join-Path $scriptDir $config.Source) $inputsDir
    Copy-Item -Force (Join-Path $scriptDir $config.Testbench) $inputsDir
    Copy-Item -Force (Join-Path $scriptDir "run_configurable_hls.tcl") $inputsDir
    Copy-Item -Force (Join-Path $scriptDir "run_configurable_vivado.tcl") $inputsDir
    Copy-Item -Force (Join-Path $scriptDir "variants.json") $inputsDir

    Write-Host "[HLS] Running $Variant ($($config.Top))"
    & $VitisHlsExe -f (Join-Path $scriptDir "run_configurable_hls.tcl") 2>&1 |
        Tee-Object -FilePath (Join-Path $logsDir "vitis_hls.log")
    if ($LASTEXITCODE -ne 0) { throw "Vitis HLS failed with exit code $LASTEXITCODE" }

    & $PythonExe (Join-Path $scriptDir "tools\collect_hls_reports.py") `
        --work-root $workRoot `
        --report-dir $reportDir `
        --variant $Variant `
        --top $config.Top `
        --part $Part `
        --hls-clock-ns $hlsClockText `
        --source $config.Source `
        --testbench $config.Testbench `
        --project $config.Project `
        --solution $config.Solution
    if ($LASTEXITCODE -ne 0) { throw "HLS report collection failed" }
}

if ($Mode -ne "HlsOnly") {
    Assert-Executable $VivadoExe "Vivado"
    if (-not (Test-Path $rtlDir)) {
        throw "RTL directory not found: $rtlDir. Run the HLS step first."
    }
    $postRoute = Join-Path $reportDir "post_route"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $postRoute
    New-Item -ItemType Directory -Force -Path $postRoute, $logsDir | Out-Null

    $env:WHT_RTL_DIR = $rtlDir
    $env:WHT_REPORT_DIR = $postRoute
    $env:WHT_VIVADO_CLOCK_NS = $VivadoClockNs.ToString([System.Globalization.CultureInfo]::InvariantCulture)

    Write-Host "[Vivado] Implementing $Variant at $VivadoClockNs ns"
    & $VivadoExe -mode batch -source (Join-Path $scriptDir "run_configurable_vivado.tcl") -notrace 2>&1 |
        Tee-Object -FilePath (Join-Path $logsDir "vivado.log")
    if ($LASTEXITCODE -ne 0) { throw "Vivado failed with exit code $LASTEXITCODE" }
}

& $PythonExe (Join-Path $scriptDir "tools\summarize_variant.py") `
    --report-dir $reportDir --variant $Variant --top $config.Top --part $Part
if ($LASTEXITCODE -ne 0) { throw "Variant summarization failed" }

& $PythonExe (Join-Path $scriptDir "tools\build_comparison.py") `
    --reports-dir (Join-Path $scriptDir "reports")
if ($LASTEXITCODE -ne 0) { throw "Comparison table generation failed" }

Write-Host "DONE: $Variant"
Write-Host "Reports: $reportDir"
