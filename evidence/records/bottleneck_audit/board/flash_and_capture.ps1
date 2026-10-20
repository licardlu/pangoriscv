<#
  flash_and_capture.ps1 -- open the UART FIRST, then program the FPGA.
  This is the only reliable order for this firmware.

  ==========================================================================
  WHY (root cause of the "P21 prints nothing on the board" runs, 2026-10-20)
  ==========================================================================
  The CoreMark image prints its whole report ONCE, about 10.7 s after the FPGA
  is configured:
    * core_main.c calls start_time() -> iterate() -> stop_time() first, and only
      then emits the ee_printf report block (nothing is printed during the run);
    * after main() returns, start.S ends in `loop: j loop`, so the report is
      never repeated.

  run_flash.ps1 blocks for the whole -TimeoutSec, because cdt_cfg.exe does not
  exit after a file-only Tcl script. Running it synchronously and only then
  starting capture_uart.ps1 puts the first serial read roughly 100 s AFTER the
  report has already gone out. The capture then returns 0 bytes, which reads as
  "the design does not transmit" -- but the design had transmitted correctly,
  long before the port was opened.

  A free-running test design (uart_free, sends every ~20 ms) is still visible
  when captured late, which is exactly why it looked "working" while every
  CoreMark run looked dead.

  Therefore: capture in the background, program while it listens, then read the
  file. -Seconds must exceed the image run time (832 iterations at 2.88
  CoreMark/MHz is 10.7 s; 60-90 s is comfortable).

  ASCII only: Windows PowerShell 5.1 decodes .ps1 with the ANSI code page.

  Usage (from this directory):
    powershell -ExecutionPolicy Bypass -File .\flash_and_capture.ps1 `
      -Sbit D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv\bitstream\pangoriscv_i768.sbit `
      -Out .\p21_score.txt -Seconds 90

  Notes:
    * COM34 is the board's CP210x. The JTAG cable (Pango USB Cable II) has its
      own virtual COM; never open that one while flashing (see mistakes-log 7.2).
    * Keep any serial terminal closed: an open COM34 makes the capture fail
      with "Access to the port is denied".
#>
param(
  [Parameter(Mandatory=$true)][string]$Sbit,
  [string]$Port = 'COM34',
  [int]$Baud = 115200,
  [int]$Seconds = 90,
  [string]$Out = 'uart_capture.txt',
  [string]$Script = '01b_program_only.tcl',
  [string]$PdsBin = 'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin',
  [int]$FlashTimeoutSec = 30,
  [int]$PreDelaySec = 6
)
$ErrorActionPreference = 'Continue'
$work = $PSScriptRoot

if (-not (Test-Path $Sbit)) { Write-Host "FAILED: bitstream not found: $Sbit"; exit 2 }
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $work $Out }

# ---- 0) the port must be free right now, otherwise the capture cannot listen --
try {
  $probe = New-Object System.IO.Ports.SerialPort $Port, $Baud, 'None', 8, 'One'
  $probe.Open()
  $probe.Close()
  $probe.Dispose()
} catch {
  Write-Host "FAILED: cannot open $Port : $($_.Exception.Message)"
  Write-Host "Close the serial terminal (or a stale capture) and retry."
  exit 2
}

# ---- 1) start the capture BEFORE programming -------------------------------
Get-Process cdt_js, cdt_cfg -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "killing leftover $($_.ProcessName) pid=$($_.Id)"
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
if (Test-Path $Out) { Remove-Item $Out -Force }
Write-Host "[1/3] capture on $Port @ $Baud for ${Seconds}s -> $Out"
$cap = Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden -ArgumentList @(
  '-ExecutionPolicy','Bypass','-File', (Join-Path $work 'capture_uart.ps1'),
  '-Port',$Port,'-Baud',$Baud,'-Seconds',$Seconds,'-Out',$Out)
Start-Sleep -Seconds $PreDelaySec

# ---- 2) program while the capture is listening ------------------------------
Write-Host "[2/3] programming $Sbit"
& powershell.exe -ExecutionPolicy Bypass -File (Join-Path $work 'run_flash.ps1') `
    -Script $Script -Sbit $Sbit -PdsBin $PdsBin -TimeoutSec $FlashTimeoutSec 2>&1 |
  Select-String -Pattern 'cfg_program|program OK|done bit|PROGRAM_ONLY_DONE|FAILED|E: ' |
  ForEach-Object { '  ' + $_.Line.Trim() }

$cfgLog = Join-Path $work 'configuration_tcl.log'
if (Test-Path $cfgLog) {
  Write-Host "  --- configuration_tcl.log ---"
  Get-Content $cfgLog | ForEach-Object { '  ' + $_ }
  if (-not (Select-String -Path $cfgLog -Pattern 'cfg_program succeed' -Quiet)) {
    Write-Host "  WARNING: no 'cfg_program succeed' in configuration_tcl.log -- the image may not be loaded."
  }
}

# ---- 3) let the capture finish, then grade it ------------------------------
Write-Host "[3/3] waiting for the capture window to close ..."
if (-not $cap.HasExited) { $cap.WaitForExit() }

$text = ''
if (Test-Path $Out) { $text = Get-Content $Out -Raw -Encoding ASCII }
Write-Host ""
Write-Host "================ captured ================"
if ($text) { Write-Host $text } else { Write-Host "(empty)" }
Write-Host "=========================================="

if (-not $text) {
  Write-Host "RESULT: EMPTY capture (0 bytes). Checklist, in order:"
  Write-Host "  1. Did the capture really overlap the boot? It must be started BEFORE"
  Write-Host "     cfg_program; a late capture cannot see a one-shot report."
  Write-Host "  2. Is the window >= the image run time (832 iter at 2.88 CM/MHz = 10.7 s)?"
  Write-Host "  3. configuration_tcl.log must contain 'cfg_program succeed'."
  Write-Host "  4. The image must be inside the bitstream: the synth log must show"
  Write-Host "     'Loading memory data from file .../program.hex' (mistakes-log 0)."
  exit 1
}

$ticks = $null
$iters = $null
$m = [regex]::Match($text, 'Total ticks\s*:\s*(\d+)')
if ($m.Success) { $ticks = [int64]$m.Groups[1].Value }
$m = [regex]::Match($text, '(?m)^Iterations\s*:\s*(\d+)')
if ($m.Success) { $iters = [int64]$m.Groups[1].Value }

$okCrc = $text -match 'Correct operation validated'
$okCrcLines = @()
foreach ($name in 'seedcrc','crclist','crcmatrix','crcstate','crcfinal') {
  $mm = [regex]::Match($text, $name + '\s*:\s*(0x[0-9a-fA-F]{4})')
  if ($mm.Success) { $okCrcLines += ($name + '=' + $mm.Groups[1].Value) }
}

Write-Host ""
Write-Host "================ verdict =================="
Write-Host ("CRCs               : " + ($okCrcLines -join ' '))
Write-Host ("Correct operation  : " + $(if ($okCrc) { 'YES' } else { 'NO' }))
if ($null -ne $ticks) { Write-Host ("Total ticks        : " + $ticks) }
if ($null -ne $iters) { Write-Host ("Iterations         : " + $iters) }
if ($null -ne $ticks -and $null -ne $iters -and $ticks -gt 0) {
  $secs = $ticks / 27e6
  $cm   = $iters / $ticks * 1e6
  Write-Host ("Run time           : {0:N3} s (must be >= 10 s)" -f $secs)
  Write-Host ("CoreMark/MHz       : {0:N4}   (= iterations / ticks * 1e6; never derive" -f $cm)
  Write-Host  "                      it from the truncated Iterations/Sec field)"
}
if (-not ($okCrc -and $ticks -and $iters)) { exit 1 }
Write-Host "OK: valid report captured."
