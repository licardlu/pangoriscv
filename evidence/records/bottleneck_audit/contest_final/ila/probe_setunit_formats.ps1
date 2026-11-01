# probe_setunit_formats.ps1 -- connected cdt_dbg session, try several dbg_set_unit value formats.
# Starts JtagServer, runs a TCL script with multiple dbg_set_unit attempts, and dismisses any
# modal Qt dialog with {ENTER} while capturing its text to a report file.
param(
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$Sbit,
  [string]$Dprj,
  [string]$OutDir
)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WProbe {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
$null=[WProbe]::SetProcessDPIAware()
New-Item -ItemType Directory -Force $OutDir | Out-Null
$js = Join-Path $PdsBin 'cdt_js.exe'
$dbg = Join-Path $PdsBin 'cdt_dbg.exe'
$fw = { param($p) ($p -replace '\\','/') }

$encA = (Get-Content 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\trigger_values.txt' | Where-Object { $_ -match '^encA_ch0_rightmost=' }) -replace '^encA_ch0_rightmost=',''
$encB = (Get-Content 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\trigger_values.txt' | Where-Object { $_ -match '^encB_ch0_leftmost=' }) -replace '^encB_ch0_leftmost=',''
$grpA = ($encA -split '(.{4})' | Where-Object { $_ }) -join '_'
$sbitFwd = & $fw $Sbit
$dprjFwd = & $fw $Dprj
$probeDprjFwd = & $fw (Join-Path $OutDir 'probe_result.dprj')
$tcl = @"
dbg_connect -ip 127.0.0.1 -port __PORT__
dbg_scan_chain
dbg_program -device 0 -file $sbitFwd
dbg_open_project -file $dprjFwd
puts "PROBE_A_RAW_BIN"
dbg_set_unit -unit 0 -func "==" -value $encA -radix 2
puts "PROBE_A_DONE"
puts "PROBE_B_GROUPED_BIN"
dbg_set_unit -unit 0 -func "==" -value $grpA -radix 2
puts "PROBE_B_DONE"
puts "PROBE_C_RAW_REV"
dbg_set_unit -unit 0 -func "==" -value $encB -radix 2
puts "PROBE_C_DONE"
dbg_save_project -file $probeDprjFwd
dbg_close
"@

Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
$jsOut = Join-Path $OutDir 'jtagserver_run.log'
$srv = Start-Process -FilePath $js -ArgumentList @('-work_dir', $OutDir) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError (Join-Path $OutDir 'jtagserver_run.err')
$port = $null
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  $txt = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue
  if ($txt -and $txt -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break }
}
if (-not $port) { Write-Host 'NO PORT'; if (-not $srv.HasExited) { $srv.Kill() }; exit 1 }
Write-Host "port=$port"
$tclPath = Join-Path $OutDir 'probe_setunit_formats.tcl'
Set-Content -Path $tclPath -Value ($tcl -replace '__PORT__', $port) -Encoding ASCII
$so = Join-Path $OutDir 'debugger_stdout.log'; $se = Join-Path $OutDir 'debugger_stderr.log'
$dbgWork = Join-Path $OutDir 'debugger_log'
New-Item -ItemType Directory -Force $dbgWork | Out-Null
$env:PANGO_SBIT = & $fw $Sbit
$psi = Start-Process -FilePath $dbg -ArgumentList @('-file', (& $fw $tclPath)) -WorkingDirectory $dbgWork -PassThru -RedirectStandardOutput $so -RedirectStandardError $se
$report = Join-Path $OutDir 'dialog_report.txt'
'' | Set-Content $report
$deadline = (Get-Date).AddSeconds(150)
$seen = @{}
while ((Get-Date) -lt $deadline -and -not $psi.HasExited) {
  Start-Sleep -Milliseconds 700
  $proc = Get-Process -Id $psi.Id -ErrorAction SilentlyContinue
  if (-not $proc) { break }
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $psi.Id)
  $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
  foreach ($w in $wins) {
    $cls = $w.Current.ClassName
    $nm = $w.Current.Name
    if ($cls -eq 'dbgMainWindow') { continue }
    $key = "$cls|$nm"
    $rect = $w.Current.BoundingRectangle
    $texts = @()
    try {
      $tt = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)))
      foreach ($t in $tt) { if ($t.Current.Name) { $texts += $t.Current.Name } }
    } catch {}
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    Add-Content $report "DIALOG class='$cls' name='$nm' rect=$rect"
    foreach ($t in $texts) { Add-Content $report "   TEXT: $t" }
    Add-Content $report '   -> dismissing with ENTER'
    try { $null = [WProbe]::SetForegroundWindow([IntPtr]$w.Current.NativeWindowHandle) } catch {}
    Start-Sleep -Milliseconds 200
    try { [System.Windows.Forms.SendKeys]::SendWait('{ENTER}') } catch {}
    Start-Sleep -Milliseconds 400
  }
}
if (-not $psi.HasExited) { try { $psi.Kill() } catch {} }
if (-not $srv.HasExited) { try { $srv.Kill() } catch {} }
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host '=== dialog_report ==='; Get-Content $report -ErrorAction SilentlyContinue
Write-Host '=== stdout ==='; Get-Content $so -ErrorAction SilentlyContinue
Write-Host '=== stderr ==='; Get-Content $se -ErrorAction SilentlyContinue
