<#
  run_area_check.ps1 -- synthesis + device_map only (no place & route).

  WHY THIS EXISTS
    LUT / FF / LUTRAM / DRM are decided by synthesis + device mapping, so this
    reproduces a delivered bitstream's resource numbers in ~3 minutes instead of
    a ~25 minute implementation.  That is what makes an area A/B practical
    (docs/architecture/module-area-plan.md, phases P2..P6).

  GUARDS (each one exists because it already caused a wrong result once)
    * Refuses to reuse a run directory that already contains device_map/ --
      one implementation = one directory, otherwise the evidence is overwritten.
    * Starts pds_shell with the run directory as its PROCESS working directory.
      PDS resolves the $readmemh paths against the process cwd, not against the
      tcl `cd`, so running from elsewhere silently produces empty memories
      (mistakes-log 0, first iron rule).
    * Requires two "Loading memory data from file" lines in compile/run.log
      (resource_check.tcl already checks this and aborts otherwise).
    * Checks the image manifest's cpu_hz when present (27 MHz board clock).

  USAGE (from anywhere)
    powershell -ExecutionPolicy Bypass -File tools\run_area_check.ps1 -RunName area_m1_off
    powershell ... -RunName area_m1_off -ImageDir build\native_software\coremark\performance\score1024

  OUTPUT
    firmware/code/build/<RunName>/            compile/ synthesize/ device_map/
    firmware/code/build/<RunName>/pds_stdout.log
    Prints the Device Utilization Summary, the RAM attribution (LUTRAM vs BRAM)
    and finally runs check_area_budget.py --mode baseline against the frozen
    baseline so area drift is visible immediately.

  ASCII only: Windows PowerShell 5.1 decodes .ps1 with the ANSI code page.
#>
param(
  [Parameter(Mandatory = $true)][string]$RunName,
  [string]$ImageDir,
  [string]$PdsBin = 'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin',
  [int]$TimeoutMin = 25
)
$ErrorActionPreference = 'Stop'

$code = Split-Path -Parent $PSScriptRoot          # tools/ -> firmware/code
$board = Join-Path $code 'platform\pango_native'
$pds = Join-Path $PdsBin 'pds_shell.exe'
$tcl = Join-Path $board 'resource_check.tcl'
if (-not (Test-Path $pds)) { throw "missing pds_shell: $pds" }
if (-not (Test-Path $tcl)) { throw "missing tcl: $tcl" }

if (-not $ImageDir) { $ImageDir = Join-Path $code 'build\native_software\coremark\performance\score1024' }
if (-not [System.IO.Path]::IsPathRooted($ImageDir)) { $ImageDir = Join-Path $code $ImageDir }
foreach ($f in 'program.hex', 'data.hex') {
  if (-not (Test-Path (Join-Path $ImageDir $f))) { throw "missing image $f in $ImageDir" }
}

$run = Join-Path $code ("build\" + $RunName)
if (Test-Path (Join-Path $run 'device_map')) {
  throw "run dir already has device_map: $run -- pick a new -RunName (one implementation = one directory)"
}
if (Test-Path $run) { Remove-Item -LiteralPath $run -Recurse -Force }
New-Item -ItemType Directory -Path $run | Out-Null

$env:PANGO_NATIVE_REPO = $code
$env:PANGO_NATIVE_BOARD_DIR = $board
$env:NATIVE_IMAGE_DIR = $ImageDir
$env:RESOURCE_RUN_DIR = $RunName

Write-Host "[1/3] pds_shell resource_check -> $run"
$proc = Start-Process -FilePath $pds -ArgumentList @('-file', $tcl) `
  -WorkingDirectory $run `
  -RedirectStandardOutput (Join-Path $run 'pds_stdout.log') `
  -RedirectStandardError (Join-Path $run 'pds_stderr.log') `
  -PassThru

$deadline = (Get-Date).AddMinutes($TimeoutMin)
$done = $false
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 5
  $out = Join-Path $run 'pds_stdout.log'
  if (Test-Path $out) {
    $txt = Get-Content $out -Raw -ErrorAction SilentlyContinue
    if ($txt -and $txt.Contains('RESOURCE_CHECK_DONE')) { $done = $true; break }
  }
  if ($proc.HasExited) { break }
}
if (-not $proc.HasExited) { try { $proc.Kill() } catch {} }

if (-not $done) {
  Write-Host "FAILED: no RESOURCE_CHECK_DONE within $TimeoutMin min"
  $out = Join-Path $run 'pds_stdout.log'
  if (Test-Path $out) { Get-Content $out -Tail 25 }
  exit 1
}

$mapLog = Join-Path $run 'device_map\run.log'
if (-not (Test-Path $mapLog)) { throw "device_map/run.log missing: $mapLog" }

# Iron rule 0: the bitstream/RAM init only exists if the compile log proves it.
# resource_check.tcl does this check itself, but under `pds_shell -file` its
# `error` is reported as a non-fatal "Flow-0163 failed to parse" and the flow
# continues, so re-check here and treat it as fatal.
$compileLog = Join-Path $run 'compile\run.log'
if (-not (Test-Path $compileLog)) { throw "compile/run.log missing: $compileLog" }
$loaded = (Select-String -Path $compileLog -Pattern 'Loading memory data from file').Count
Write-Host "[check] memory images loaded: $loaded (need 2)"
if ($loaded -lt 2) { throw "only $loaded of 2 memory images loaded -- empty program/data memory" }

Write-Host ""
Write-Host "[2/3] device utilisation"
$lines = Get-Content $mapLog
$at = ($lines | Select-String -Pattern 'Device Utilization Summary' | Select-Object -First 1).LineNumber
if (-not $at) { throw "no utilisation summary in $mapLog" }
$lines[($at - 1)..([Math]::Min($at + 11, $lines.Count - 1))] | ForEach-Object { '  ' + $_.TrimEnd() }

Write-Host ""
Write-Host "[3/3] RAM attribution (LUTRAM vs BRAM)"
$util = Join-Path $run 'synthesize\apm_drm_lutram_utilization.log'
if (Test-Path $util) {
  Select-String -Path $util -Pattern 'data_ram/mem|program_ram/mem|instruction_cache/|data_cache/' |
    Select-Object -First 12 | ForEach-Object { '  ' + $_.Line.Trim() }
} else {
  Write-Host "  (no apm_drm_lutram_utilization.log)"
}

Write-Host ""
Write-Host "check_area_budget.py --mode baseline (drift gate):"
$py = $env:DSH_PYTHON
if (-not $py) { $py = 'python' }
& $py (Join-Path $PSScriptRoot 'check_area_budget.py') --mode baseline --from-used $mapLog
exit $LASTEXITCODE
