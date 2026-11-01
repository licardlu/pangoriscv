# capture_and_export.ps1 -- one-shot ILA capture + GUI export of sample data (ASCII/TXT).
# Flow: start JtagServer -> run capture TCL (trigger=PC==0x1078 from dprj) -> wait for
# "trigger successful" -> drive Fabric Debugger GUI via UI Automation + mouse clicks ->
# File/Export Sample Data -> ASCII -> Save -> copy exported file to OutDir -> kill procs.
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$Sbit,
  [Parameter(Mandatory=$true)][string]$Fic,
  [Parameter(Mandatory=$true)][string]$Dprj,
  [Parameter(Mandatory=$true)][string]$Tcl,
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$ExportName = 'ila_samples_ascii.txt',
  [int]$CaptureTimeoutSec = 120
)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
$null = [Win32]::SetProcessDPIAware()
function Click-Rect([System.Windows.Rect]$r) {
  $x = [int]($r.X + $r.Width/2); $y = [int]($r.Y + $r.Height/2)
  $null = [Win32]::SetCursorPos($x, $y); Start-Sleep -Milliseconds 120
  [Win32]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60
  [Win32]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
  Write-Host "    click at ($x,$y)"
}
function Fwd([string]$p) { return ($p -replace '\\','/') }
$js  = Join-Path $PdsBin 'cdt_js.exe'
$dbg = Join-Path $PdsBin 'cdt_dbg.exe'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$logDir = Join-Path $OutDir 'debugger_log'
New-Item -ItemType Directory -Force $logDir | Out-Null
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force; Write-Host "killed leftover $($_.ProcessName) $($_.Id)" }
Start-Sleep -Seconds 2

# 1) JtagServer
$jsOut = Join-Path $OutDir 'jtagserver_run.log'; $jsErr = Join-Path $OutDir 'jtagserver_run.err'
foreach ($f in @($jsOut,$jsErr)) { if (Test-Path $f) { Remove-Item $f -Force } }
Write-Host '[1] starting JtagServer'
$srv = Start-Process -FilePath $js -ArgumentList @('-work_dir',$OutDir) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError $jsErr
$port = $null
for ($i=0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; $t = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue; if ($t -and $t -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break } }
if (-not $port) { Write-Host 'FAILED to get port'; if (-not $srv.HasExited) { $srv.Kill() }; exit 1 }
Write-Host "    port=$port"

# 2) capture TCL (with hold at the end so the GUI stays alive for the export step)
$tclText = Get-Content $Tcl -Raw
$tclText = $tclText -replace '__IP__','127.0.0.1' -replace '__PORT__',$port -replace '__SBIT__',(Fwd $Sbit) -replace '__FIC__',(Fwd $Fic) -replace '__DPRJ__',(Fwd $Dprj)
$tmpTcl = Join-Path $OutDir 'capture_run.tcl'
Set-Content -Path $tmpTcl -Value $tclText -Encoding ASCII
$dbgOut = Join-Path $OutDir 'debugger_stdout.log'; $dbgErr = Join-Path $OutDir 'debugger_stderr.log'
foreach ($f in @($dbgOut,$dbgErr)) { if (Test-Path $f) { Remove-Item $f -Force } }
Write-Host '[2] starting Fabric Debugger + capture TCL'
$cli = Start-Process -FilePath $dbg -ArgumentList @('-file',$tmpTcl) -WorkingDirectory $logDir -PassThru -RedirectStandardOutput $dbgOut -RedirectStandardError $dbgErr

# 3) wait for trigger
Write-Host '[3] waiting for trigger ...'
$triggered = $false
$deadline = (Get-Date).AddSeconds($CaptureTimeoutSec)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $txt = Get-Content $dbgOut -Raw -ErrorAction SilentlyContinue
  if ($txt -match 'trigger successful') { $triggered = $true; break }
  if ($cli.HasExited) { Write-Host "    cdt_dbg exited early"; break }
}
if (-not $triggered) { Write-Host 'TRIGGER NOT OBSERVED'; }
else { Write-Host '    trigger observed' }
Start-Sleep -Seconds 4

# 4) GUI automation: File -> Export Sample Data -> ASCII -> OK -> save path
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $cli.Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if ($win) { Write-Host "    main window: '$($win.Current.Name)'" } else { $clsCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'dbgMainWindow'); $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $clsCond) }
if (-not $win) { Write-Host 'main window not found'; exit 1 }
$miCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuItem)
function Find-Item([string]$name) { return ($win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond) | Where-Object { $_.Current.Name -eq $name } | Select-Object -First 1) }
$file = Find-Item 'File'
Write-Host '[4] opening File menu'
Click-Rect $file.Current.BoundingRectangle
Start-Sleep -Milliseconds 900
$exp = Find-Item 'Export Sample Data'
if (-not $exp) { Write-Host 'export item not found'; exit 1 }
Click-Rect $exp.Current.BoundingRectangle
Start-Sleep -Seconds 2

# find Export dialog among top-level windows of this PID
function Get-PidWindows {
  $all = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
  return @($all | Where-Object { $_.Current.ProcessId -eq $cli.Id })
}
$dlg = $null
foreach ($w in Get-PidWindows) { if ($w.Current.Name -eq 'Export') { $dlg = $w; break } }
if (-not $dlg) { Write-Host 'Export dialog not found'; Get-PidWindows | ForEach-Object { Write-Host "   window '$($_.Current.Name)' class=$($_.Current.ClassName)" }; exit 1 }
Write-Host "    dialog: $($dlg.Current.Name)"
$rCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::RadioButton)
$ascii = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $rCond) | Where-Object { $_.Current.Name -match 'ASCII' } | Select-Object -First 1
if ($ascii) { Write-Host "    selecting ASCII"; Click-Rect $ascii.Current.BoundingRectangle; Start-Sleep -Milliseconds 400 } else { Write-Host 'ASCII radio not found' }
$bCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$ok = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bCond) | Where-Object { $_.Current.Name -eq 'OK' } | Select-Object -First 1
if (-not $ok) { Write-Host 'OK button not found'; exit 1 }
$exportPath = Join-Path $OutDir $ExportName
Write-Host "    clicking OK (target $exportPath)"
Click-Rect $ok.Current.BoundingRectangle
Start-Sleep -Seconds 2

# 5) save dialog: find edit, set path, press Save (or Enter)
$saveDlg = $null
foreach ($w in Get-PidWindows) { if ($w.Current.Name -match 'Export|Save|Save As' -and $w.Current.Name -ne 'Export') { $saveDlg = $w; break } }
if (-not $saveDlg) { foreach ($w in Get-PidWindows) { if ($w.Current.ClassName -match '32770|#32770' -and $w.Current.Name -ne 'Export') { $saveDlg = $w; break } } }
if ($saveDlg) {
  Write-Host "    save dialog: '$($saveDlg.Current.Name)' class=$($saveDlg.Current.ClassName)"
  $eCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
  $edit = $saveDlg.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $eCond)
  if ($edit) {
    try { $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($exportPath); Write-Host "    set filename" } catch { Write-Host "    set value failed: $_" }
    Start-Sleep -Milliseconds 500
  }
  $saveBtn = $saveDlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bCond) | Where-Object { $_.Current.Name -match '^Save$|^保存$|^确定$|^OK$' } | Select-Object -First 1
  if ($saveBtn) { Click-Rect $saveBtn.Current.BoundingRectangle; Write-Host "    clicked $($saveBtn.Current.Name)" }
  else { [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Write-Host '    pressed ENTER to save' }
  Start-Sleep -Seconds 3
} else {
  Write-Host '    save dialog not found; windows:'
  Get-PidWindows | ForEach-Object { Write-Host "      '$($_.Current.Name)' class=$($_.Current.ClassName)" }
}
# 6) collect results
Start-Sleep -Seconds 1
Write-Host '[5] results'
if (Test-Path $exportPath) { $fi = Get-Item $exportPath; Write-Host "    exported: $($fi.FullName) $($fi.Length) B" } else { Write-Host "    exported file NOT found: $exportPath" }
Get-ChildItem $OutDir -File | Select-Object Name,Length | Format-Table -AutoSize
# 7) teardown
if (-not $cli.HasExited) { try { $cli.Kill() } catch {} }
if (-not $srv.HasExited) { try { $srv.Kill() } catch {} }
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'DONE'
