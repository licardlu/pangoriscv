# board_verify.ps1 -- one command: preflight the JTAG cable, program the FPGA,
# capture the UART, validate the CoreMark report, write board_result.json.
#
# WHY THIS EXISTS
# ---------------
# Every board round so far ended in "No devices detected", which has three very
# different causes and only one of them is the FPGA:
#   (a) the USB download cable is not enumerated by Windows at all
#       -> `The cable List :` in the cfg_connect output is EMPTY
#       -> nothing in the software can fix it, the cable has to be plugged in;
#   (b) the cable is there but the server is on another port
#       -> `connection was refused` (see mistakes-log 91: the scan script sets
#          its own port unless PANGO_JTAG_PORT overrides it);
#   (c) the cable and the FPGA talk but the board is unpowered
#       -> `JtagServer-0306: No devices detected` with a NON-empty cable list.
# This script separates (a)/(b) from (c) BEFORE programming, so a failed run
# never leaves us guessing again.
#
# ORDER MATTERS: the UART must be listening before configuration, because the
# CoreMark image prints its whole report once, ~10.7 s after configuration, and
# start.S then spins forever.  flash_and_capture.ps1 already implements that
# order; this script only adds the preflight and the result check around it.
#
# USAGE (from the repository root):
#   powershell -ExecutionPolicy Bypass -File firmware\code\tools\board_verify.ps1 `
#       -Sbit bitstream\pangoriscv_board50_i2800_5p248.sbit -FreqMhz 50 -Iterations 2800
#
# Exit codes: 0 = measured and all five CRCs good; 3 = cable not enumerated;
#             4 = programmed but the report was incomplete / CRC mismatch;
#             5 = could not open the UART.
# ASCII only: Windows PowerShell 5.1 decodes .ps1 with the ANSI code page.

param(
  [Parameter(Mandatory=$true)][string]$Sbit,
  [string]$Port = 'COM34',
  [int]$Baud = 115200,
  [int]$Seconds = 90,
  [double]$FreqMhz = 50.0,
  [int]$Iterations = 2800,
  [int]$JtagPort = 65420,
  [string]$Out = '',
  [switch]$SkipProgram
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$boarddir = Join-Path $repo 'evidence\records\bottleneck_audit\board'
$pdsbin = 'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin'
if (-not (Test-Path $pdsbin)) { $pdsbin = 'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin' }
if ($Out -eq '') {
  $Out = Join-Path $boarddir ('board_result_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
}

function Write-Step([string]$m) { Write-Host ("[board] " + $m) }

# ---------------------------------------------------------------- 1. cable ---
$js = Get-Process cdt_js -ErrorAction SilentlyContinue
if (-not $js) {
  Write-Step "starting JtagServer on port $JtagPort"
  $jsExe = Join-Path $pdsbin 'cdt_js.exe'
  Start-Process -FilePath $jsExe -ArgumentList @('-port', "$JtagPort", '-work_dir', $boarddir) `
                -WorkingDirectory $boarddir -WindowStyle Hidden | Out-Null
  Start-Sleep -Seconds 4
}

$env:PANGO_JTAG_PORT = "$JtagPort"
$probeTcl = Join-Path $boarddir '00b_cable_probe.tcl'
$probeOut = Join-Path $boarddir 'board_verify_cable_probe.log'
Push-Location $boarddir
& (Join-Path $pdsbin 'cdt_cfg.exe') -file '00b_cable_probe.tcl' -ip 127.0.0.1 `
    -port "$JtagPort" -work_dir . *> $probeOut
Pop-Location

$probe = Get-Content $probeOut -Raw -ErrorAction SilentlyContinue
$cableSeen = $false
if ($probe -match 'The cable List\s*:\s*(\S.*)$') {
  $rest = $Matches[1].Trim()
  if ($rest -ne '' -and $rest -notmatch '^COMMAND') { $cableSeen = $true }
}
if (-not $cableSeen) {
  Write-Host ""
  Write-Host "STOP: no USB download cable is enumerated by Windows." -ForegroundColor Red
  Write-Host "  evidence: $probeOut  (the 'The cable List' line is empty)"
  Write-Host ""
  Write-Host "  This is not a board-power problem. Fix in this order:"
  Write-Host "    1. plug the Pango USB Cable II into THIS machine (not only the board side);"
  Write-Host "    2. check Device Manager for an FTDI / Pango / USB Serial Converter entry;"
  if (Test-Path (Join-Path $pdsbin '..\driver\dpinst-amd64.exe')) {
    Write-Host ("       no entry -> run " + (Join-Path $pdsbin '..\driver\dpinst-amd64.exe'))
  }
  Write-Host "    3. the cable exposes its own virtual COM port; COM34 is the board UART."
  Write-Host ""
  Write-Host "  Re-run this script once the cable shows up; it does the rest."
  exit 3
}
Write-Step "cable present"

# ------------------------------------------------------- 2. program + UART ---
if (-not $SkipProgram) {
  $sbitFull = (Resolve-Path $Sbit).Path
  Write-Step "flashing $sbitFull with the UART listening first"
  $env:PANGO_SBIT = $sbitFull.Replace('\','/')
  & powershell -ExecutionPolicy Bypass -File (Join-Path $boarddir 'flash_and_capture.ps1') `
      -Sbit $sbitFull -Port $Port -Seconds $Seconds -Out $Out
} else {
  Write-Step "-SkipProgram: only reading $Out"
}

if (-not (Test-Path $Out)) {
  Write-Host "STOP: no UART capture at $Out (port $Port could not be opened?)" -ForegroundColor Red
  exit 5
}
$text = Get-Content $Out -Raw
if ($null -eq $text) { $text = '' }

# ------------------------------------------------------------ 3. validate ---
function Grab([string]$pattern) {
  if ($text -match $pattern) { return $Matches[1] } else { return $null }
}
$ticks   = Grab 'Total ticks\s*:\s*([0-9]+)'
$iters   = Grab 'Iterations\s*:\s*([0-9]+)'
$seed    = Grab 'seedcrc\s*:\s*(0x[0-9a-fA-F]+)'
$clist   = Grab 'crclist\s*:\s*(0x[0-9a-fA-F]+)'
$cmatrix = Grab 'crcmatrix\s*:\s*(0x[0-9a-fA-F]+)'
$cstate  = Grab 'crcstate\s*:\s*(0x[0-9a-fA-F]+)'
$cfinal  = Grab 'crcfinal\s*:\s*(0x[0-9a-fA-F]+)'

$want = @{ '0x54414c55' = 'seedcrc'; '0xe714' = 'crclist'; '0x1fd7' = 'crcmatrix';
           '0x8e3a' = 'crcstate'; '0x4983' = 'crcfinal' }
$crcOk = $true
foreach ($pair in @(@('seedcrc',$seed),@('crclist',$clist),@('crcmatrix',$cmatrix),
                    @('crcstate',$cstate),@('crcfinal',$cfinal))) {
  $name = $pair[0]; $val = $pair[1]
  if ($null -eq $val) { $crcOk = $false; Write-Host "  $name : MISSING" -ForegroundColor Red; continue }
  $expect = ($want.Keys | Where-Object { $want[$_] -eq $name })
  $ok = $false
  foreach ($k in $want.Keys) { if ($want[$k] -eq $name -and $k.ToLower() -eq $val.ToLower()) { $ok = $true } }
  if ($ok) { Write-Host "  $name : $val  OK" -ForegroundColor Green }
  else { $crcOk = $false; Write-Host "  $name : $val  MISMATCH" -ForegroundColor Red }
}

$summary = @()
$summary += "sbit        = $Sbit"
$summary += "uart_port   = $Port"
$summary += "capture     = $Out"
if ($null -ne $ticks) {
  $t = [int64]$ticks
  $it = if ($null -ne $iters) { [int]$iters } else { $Iterations }
  $cmMHz = $it * 1e6 / $t
  $secs  = $t / ($FreqMhz * 1e6)
  $summary += "iterations  = $it"
  $summary += "total_ticks = $t"
  $summary += "ticks_per_it= {0:N1}" -f ($t / $it)
  $summary += "coremark_mhz= {0:F4}" -f $cmMHz
  $summary += ("run_seconds = {0:F2}  (>=10 s required: {1})" -f $secs, ($secs -ge 10))
  $summary += ("coremark_luts = n/a here, take LUTs from the resource report of the SAME build")
} else {
  $summary += "total_ticks = MISSING (no CoreMark report in the capture)"
}
$summary += "crc_all_good = $crcOk"
$summary | ForEach-Object { Write-Host $_ }
$jsonPath = [System.IO.Path]::ChangeExtension($Out, '.json')
(@{ sbit=$Sbit; uart_port=$Port; capture=$Out; total_ticks=$ticks; iterations=$iters;
    seedcrc=$seed; crclist=$clist; crcmatrix=$cmatrix; crcstate=$cstate; crcfinal=$cfinal;
    crc_all_good=$crcOk; freq_mhz=$FreqMhz } | ConvertTo-Json) | Set-Content -Path $jsonPath -Encoding ASCII
Write-Host "wrote $jsonPath"

if ($null -eq $ticks) { exit 4 }
if (-not $crcOk) { exit 4 }
exit 0
