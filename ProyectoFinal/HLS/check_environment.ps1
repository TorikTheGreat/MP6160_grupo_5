param(
    [string]$VitisHlsExe = "vitis_hls",
    [string]$VivadoExe = "vivado",
    [string]$PythonExe = "python"
)

foreach ($entry in @(
    @{ Name = "Python 3"; Exe = $PythonExe },
    @{ Name = "Vitis HLS"; Exe = $VitisHlsExe },
    @{ Name = "Vivado"; Exe = $VivadoExe }
)) {
    if ((Test-Path $entry.Exe) -or (Get-Command $entry.Exe -ErrorAction SilentlyContinue)) {
        Write-Host "[OK] $($entry.Name): $($entry.Exe)"
    }
    else {
        Write-Host "[MISSING] $($entry.Name): $($entry.Exe)"
    }
}
Write-Host "`nTarget part configured: xck26-sfvc784-2LV-c"
Write-Host "A successful synthesis run is still required to confirm device support and licensing."
