<#
  run_flash.ps1 -- one-shot: start JtagServer -> parse its printed TCP port ->
  run one Tcl script with cdt_cfg.exe -> kill the server.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\run_flash.ps1 -Script 00_scan_chain.tcl
    powershell -ExecutionPolicy Bypass -File .\run_flash.ps1 -Script 01_program_sram.tcl
    powershell -ExecutionPolicy Bypass -File .\run_flash.ps1 -Script 03_program_flash.tcl

  WARNING: on THIS laptop starting cdt_js.exe has triggered a kernel bugcheck
  (0x139 / ftdibus.sys) within ~30 s. See ..\CRASH_ANALYSIS_AND_MITIGATION.md
  and ..\ROOT_CAUSE_ftdibus.md. Prefer running this kit on another PC.

  NOTE: -port is NOT honoured by cdt_js.exe; the server prints the real port in
  its log and this script parses that line (regex "use port\s*:\s*(\d+)").
  NOTE: cdt_cfg.exe may not exit after a file-only Tcl script, so the client is
  killed after -TimeoutSec and success is judged from configuration_tcl.log.

  IMPORTANT -- this script BLOCKS for up to -TimeoutSec (default 120 s), because
  the client above is killed only at that timeout. Do NOT start a UART capture
  after it returns: the CoreMark report is sent ONCE, ~10.7 s after configuration
  (core_main.c prints only after iterate(); start.S then spins in `j loop`), so a
  late capture reads 0 bytes even though the design printed correctly.
  Use flash_and_capture.ps1, which opens the port first and then programs.
  See docs/lessons/mistakes-log.md 7.6.

  ASCII only on purpose: Windows PowerShell 5.1 decodes .ps1 as the ANSI codepage,
  so non-ASCII comments in a BOM-less file corrupt the parse.
#>
param(
  [Parameter(Mandatory=$true)][string]$Script,
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$Sbit   = 'E:\file\pango\project\01_code\tinyriscv_axi4\build\pango_native\generate_bitstream\pango_native_top.sbit',
  [int]$TimeoutSec = 120
)
$ErrorActionPreference = 'Continue'
$work = $PSScriptRoot
$js   = Join-Path $PdsBin 'cdt_js.exe'
$cfg  = Join-Path $PdsBin 'cdt_cfg.exe'
foreach ($f in @($js,$cfg)) { if (-not (Test-Path $f)) { throw "missing $f" } }
$tcl = Join-Path $work $Script
if (-not (Test-Path $tcl)) { throw "missing script $tcl" }

$env:PANGO_SBIT = $Sbit -replace '\\','/'
$jsOut = Join-Path $work 'jtagserver_run.log'
$jsErr = Join-Path $work 'jtagserver_run.err'
$cfgLog = Join-Path $work 'configuration_tcl.log'
foreach ($f in @($jsOut,$jsErr,$cfgLog)) { if (Test-Path $f) { Remove-Item $f -Force } }

Get-Process cdt_js,cdt_cfg -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "killing leftover $($_.ProcessName) pid=$($_.Id)"
  Stop-Process -Id $_.Id -Force
}

Write-Host "[1/3] starting JtagServer (this is the step that can bugcheck the PC) ..."
$srv = Start-Process -FilePath $js -ArgumentList @('-work_dir',$work) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError $jsErr

$port = $null
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  if ($srv.HasExited) { Write-Host "    server exited early, code=$($srv.ExitCode)"; break }
  $txt = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue
  if ($txt -and $txt -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break }
}
if (-not $port) {
  Write-Host "FAILED to parse the port from $jsOut -- check that log"
  if (-not $srv.HasExited) { $srv.Kill() }
  exit 1
}
$env:PANGO_JTAG_PORT = $port
Write-Host "    server port = $port"

Write-Host "[2/3] running $Script (timeout ${TimeoutSec}s) ..."
$cfgOut = Join-Path $work ("$Script.out.txt")
$cfgErr = Join-Path $work ("$Script.err.txt")
$cli = Start-Process -FilePath $cfg -ArgumentList @('-file',$tcl,'-ip','127.0.0.1','-port',$port,'-work_dir',$work) -PassThru -RedirectStandardOutput $cfgOut -RedirectStandardError $cfgErr
$waited = 0
while (-not $cli.HasExited -and $waited -lt $TimeoutSec) { Start-Sleep -Seconds 1; $waited++ }
if ($cli.HasExited) {
  Write-Host "    cdt_cfg exit code = $($cli.ExitCode) after ${waited}s"
} else {
  Write-Host "    cdt_cfg still running after ${waited}s (expected for file-only commands) -- killing it"
  try { $cli.Kill() } catch {}
}

Write-Host "[3/3] stopping JtagServer ..."
if (-not $srv.HasExited) { try { $srv.Kill() } catch {} }
Get-Process cdt_js,cdt_cfg -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host ""
Write-Host "===== client stdout ($cfgOut) ====="
if (Test-Path $cfgOut) { Get-Content $cfgOut } else { Write-Host "(no stdout file)" }
Write-Host "===== client stderr ($cfgErr) ====="
if (Test-Path $cfgErr) { Get-Content $cfgErr } else { Write-Host "(no stderr file)" }
Write-Host "===== configuration_tcl.log (authoritative result) ====="
if (Test-Path $cfgLog) { Get-Content $cfgLog } else { Write-Host "(no configuration_tcl.log -- server likely never reached the client)" }
