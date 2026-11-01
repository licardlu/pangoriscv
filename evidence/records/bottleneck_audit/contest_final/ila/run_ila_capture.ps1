# run_ila_capture.ps1 -- start JtagServer, substitute the capture TCL template,
# run it with cdt_dbg.exe (Fabric Debugger), collect logs, kill everything.
# Same JtagServer handshake as board\run_flash.ps1 (port is parsed from its log).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run_ila_capture.ps1 `
#     -Template .\capture_smoke.tcl -Sbit <debug.sbit> -Fic .\pangoriscv_coremark.fic `
#     -OutDir ..\logs\ila_capture_smoke -TimeoutSec 180
param(
  [Parameter(Mandatory=$true)][string]$Template,
  [Parameter(Mandatory=$true)][string]$Sbit,
  [Parameter(Mandatory=$true)][string]$Fic,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$Dprj = '',
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [int]$TimeoutSec = 180,
  [string]$Screenshots = '',
  [string]$TrigVal = ''
)
$ErrorActionPreference = 'Continue'
$work = $PSScriptRoot
$js   = Join-Path $PdsBin 'cdt_js.exe'
$dbg  = Join-Path $PdsBin 'cdt_dbg.exe'
foreach ($f in @($js,$dbg)) { if (-not (Test-Path $f)) { throw "missing $f" } }
foreach ($f in @($Template,$Sbit,$Fic)) { if (-not (Test-Path $f)) { throw "missing $f" } }
if (-not $Dprj) { $Dprj = Join-Path $OutDir 'ila_capture.dprj' }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$logDir = Join-Path $OutDir 'debugger_log'
New-Item -ItemType Directory -Force $logDir | Out-Null

# forward slashes for Tcl, single quotes are fine in Tcl braces
function Fwd([string]$p) { return ($p -replace '\\','/') }
function Take-Screen([string]$path) {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    try { $ws = New-Object -ComObject WScript.Shell; $null = $ws.AppActivate('Fabric Debugger'); Start-Sleep -Milliseconds 700 } catch {}
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "    screenshot: $path"
  } catch { Write-Host "    screenshot failed: $_" }
}
$tclText = Get-Content $Template -Raw
$tclText = $tclText -replace '__IP__','127.0.0.1' -replace '__PORT__','__PORT_VALUE__'
$tclText = $tclText -replace '__SBIT__', (Fwd $Sbit)
$tclText = $tclText -replace '__FIC__',  (Fwd $Fic)
$tclText = $tclText -replace '__DPRJ__', (Fwd $Dprj)
if ($TrigVal) { $tclText = $tclText -replace '__TRIGVAL__', $TrigVal }
$tmpTcl = Join-Path $OutDir 'capture_run.tcl'

$env:PANGO_SBIT = Fwd $Sbit
$jsOut = Join-Path $OutDir 'jtagserver_run.log'
$jsErr = Join-Path $OutDir 'jtagserver_run.err'
foreach ($f in @($jsOut,$jsErr)) { if (Test-Path $f) { Remove-Item $f -Force } }

Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "killing leftover $($_.ProcessName) pid=$($_.Id)"
  Stop-Process -Id $_.Id -Force
}

Write-Host "[1/4] starting JtagServer (this is the step that can bugcheck the PC) ..."
$srv = Start-Process -FilePath $js -ArgumentList @('-work_dir',$work) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError $jsErr
$port = $null
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  if ($srv.HasExited) { Write-Host "    server exited early, code=$($srv.ExitCode)"; break }
  $txt = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue
  if ($txt -and $txt -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break }
}
if (-not $port) {
  Write-Host "FAILED to parse the port from $jsOut"
  if (-not $srv.HasExited) { $srv.Kill() }
  exit 1
}
Write-Host "    server port = $port"
Set-Content -Path $tmpTcl -Value ($tclText -replace '__PORT_VALUE__',$port) -Encoding ASCII

Write-Host "[2/4] running capture TCL with Fabric Debugger (timeout ${TimeoutSec}s) ..."
$dbgOut = Join-Path $OutDir 'debugger_stdout.log'
$dbgErr = Join-Path $OutDir 'debugger_stderr.log'
foreach ($f in @($dbgOut,$dbgErr)) { if (Test-Path $f) { Remove-Item $f -Force } }
$cli = Start-Process -FilePath $dbg -ArgumentList @('-file',$tmpTcl) -WorkingDirectory $logDir -PassThru -RedirectStandardOutput $dbgOut -RedirectStandardError $dbgErr
$waited = 0
$screenTimes = @()
if ($Screenshots) { $screenTimes = $Screenshots -split ',' | ForEach-Object { [int]$_ } }
while (-not $cli.HasExited -and $waited -lt $TimeoutSec) {
  Start-Sleep -Seconds 1; $waited++
  if ($screenTimes -contains $waited) { Take-Screen (Join-Path $OutDir ('screen_t{0}.png' -f $waited)) }
}
if ($cli.HasExited) {
  Write-Host "    cdt_dbg exit code = $($cli.ExitCode) after ${waited}s"
} else {
  Write-Host "    cdt_dbg still running after ${waited}s -- killing it"
  try { $cli.Kill() } catch {}
}
Start-Sleep -Seconds 2

Write-Host "[3/4] stopping JtagServer ..."
if (-not $srv.HasExited) { try { $srv.Kill() } catch {} }
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "[4/4] results ..."
foreach ($name in @('debugger_stdout.log','debugger_stderr.log','jtagserver_run.log','jtagserver_run.err')) {
  $p = Join-Path $OutDir $name
  Write-Host "----- $name -----"
  if (Test-Path $p) { Get-Content $p } else { Write-Host "(missing)" }
}
Get-ChildItem $logDir -Recurse -File -ErrorAction SilentlyContinue | Select-Object FullName,Length | Format-Table -AutoSize
if (Test-Path $Dprj) { Write-Host "project saved: $Dprj ($((Get-Item $Dprj).Length) B)" }
Write-Host "DONE"


