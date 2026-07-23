param(
    [string]$ImplDir = "$PSScriptRoot\vivado_work"
)

$ErrorActionPreference = "Stop"

$utilRpt = Join-Path $ImplDir "utilization_post_route.rpt"
$timingRpt = Join-Path $ImplDir "timing_post_route.rpt"
$criticalRpt = Join-Path $ImplDir "timing_critical_path.rpt"
$summaryFile = Join-Path $ImplDir "impl_summary.txt"
$outMd = Join-Path $PSScriptRoot "metrics_impl.md"

if (-not (Test-Path $utilRpt)) { throw "Missing file: $utilRpt" }
if (-not (Test-Path $timingRpt)) { throw "Missing file: $timingRpt" }
if (-not (Test-Path $criticalRpt)) { throw "Missing file: $criticalRpt" }

$utilText = Get-Content $utilRpt -Raw
$timingText = Get-Content $timingRpt -Raw
$criticalText = Get-Content $criticalRpt -Raw
$summaryText = ""
if (Test-Path $summaryFile) {
    $summaryText = Get-Content $summaryFile -Raw
}

function Get-MatchValue {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Default = "N/A"
    )

    $m = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success -and $m.Groups.Count -ge 2) {
        return $m.Groups[1].Value.Trim()
    }
    return $Default
}

# Resource extraction from report_utilization table.
$lut = Get-MatchValue -Text $utilText -Pattern "\|\s*CLB LUTs\*?\s*\|\s*([0-9,]+)\s*\|"
$ff = Get-MatchValue -Text $utilText -Pattern "\|\s*CLB Registers\s*\|\s*([0-9,]+)\s*\|"
$dsp = Get-MatchValue -Text $utilText -Pattern "\|\s*DSP(?:\s+Slices|s)?\s*\|\s*([0-9,]+)\s*\|"
$bram = Get-MatchValue -Text $utilText -Pattern "\|\s*Block RAM Tile\s*\|\s*([0-9,]+(?:\.[0-9]+)?)\s*\|"

# Timing extraction from critical path report (does not depend on target clock line).
$datapathNs = Get-MatchValue -Text $criticalText -Pattern "Data Path Delay:\s*([0-9.]+)ns"
$logicNs = Get-MatchValue -Text $criticalText -Pattern "logic\s*([0-9.]+)ns"
$routeNs = Get-MatchValue -Text $criticalText -Pattern "route\s*([0-9.]+)ns"
$wnsNs = Get-MatchValue -Text $summaryText -Pattern "wns_ns\s*=\s*(-?[0-9.]+)"

if ($datapathNs -eq "N/A") {
    $datapathNs = Get-MatchValue -Text $summaryText -Pattern "datapath_delay_ns\s*=\s*([0-9.]+)"
}

if ($wnsNs -eq "N/A") {
    $wnsNs = Get-MatchValue -Text $timingText -Pattern "Slack\s*\((?:MET|VIOLATED)\)\s*:\s*(-?[0-9.]+)ns"
}

if ($wnsNs -eq "N/A") {
    $wnsNs = Get-MatchValue -Text $timingText -Pattern "\n\s*(-?[0-9.]+)\s+[-0-9.]+\s+\d+\s+\d+\s+[-0-9.]+\s+[-0-9.]+\s+\d+\s+\d+"
}

$fmaxMHz = "N/A"
if ($datapathNs -ne "N/A") {
    try {
        $d = [double]::Parse($datapathNs, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($d -gt 0.0) {
            $fmaxMHz = [math]::Round(1000.0 / $d, 2)
        }
    }
    catch {
        $fmaxMHz = "N/A"
    }
}

$lines = @(
    "# W2 Implemented Hardware Metrics (Post-Route)",
    "",
    "Source: Vivado 2024.1 post-route reports.",
    "",
    "| Metric | Value |",
    "|---|---|",
    "| Critical data path delay (ns) | $datapathNs |",
    "| Implemented fmax (MHz) | $fmaxMHz |",
    "| WNS (ns) | $wnsNs |",
    "| LUT | $lut |",
    "| FF | $ff |",
    "| DSP | $dsp |",
    "| BRAM tile | $bram |",
    "",
    "## Critical path decomposition",
    "",
    "- Logic delay (ns): $logicNs",
    "- Routing delay (ns): $routeNs",
    "",
    "## Notes",
    "",
    "- fmax is computed as 1000 / critical_data_path_delay.",
    "- This post-route value is more representative than csynth timing estimates."
)

Set-Content -Path $outMd -Value ($lines -join "`r`n") -Encoding ASCII
Write-Host "Implemented metrics written to: $outMd"
