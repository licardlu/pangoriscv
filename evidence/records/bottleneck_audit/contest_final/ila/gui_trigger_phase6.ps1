# gui_trigger_phase6.ps1 -- full pipeline: launch debugger, enable match unit, set value via GUI,
# run capture, poll console for 'trigger successful', stop, save project, export ASCII sample data.
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$DprjIn = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\logs\ila_capture_encA3\ila_capture.dprj',
  [string]$Sbit   = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila_debug\src\build\pango_native\generate_bitstream\pangoriscv_top.sbit',
  [string]$ScriptsDir = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila',
  [ValidateSet('encA','encB')][string]$Orientation = 'encA',
  [int]$WaitTriggerSec = 20,
  [string]$DprjOut = '',
  [string]$ExportName = 'ila_samples_triggered.prn'
)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $OutDir 'debugger_log') | Out-Null
$log = Join-Path $OutDir "gui_trigger_phase6_$Orientation.log"
function L([string]$m) { $ts = (Get-Date).ToString('HH:mm:ss'); "$ts $m" | Tee-Object -FilePath $log -Append }
if (-not $DprjOut) { $DprjOut = Join-Path $OutDir 'ila_capture_triggered.dprj' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class W9 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int cx, int cy, bool rep);
  public class WinInfo { public IntPtr H; public uint Pid; public string Cls; public string Title; public int X,Y,W,Ht; public bool Vis; }
  public static List<WinInfo> List(uint pidFilter) {
    var list = new List<WinInfo>();
    EnumWindows((h,l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pidFilter != 0 && pid != pidFilter) return true;
      var sb = new StringBuilder(512); GetClassName(h, sb, 512);
      var tb = new StringBuilder(512); GetWindowText(h, tb, 512);
      RECT r; GetWindowRect(h, out r);
      var w = new WinInfo{H=h,Pid=pid,Cls=sb.ToString(),Title=tb.ToString(),X=r.L,Y=r.T,W=r.R-r.L,Ht=r.B-r.T,Vis=IsWindowVisible(h)};
      list.Add(w); return true;
    }, IntPtr.Zero);
    return list;
  }
  public static void Click(IntPtr h, int x, int y) {
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(180);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(70);
    mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(220);
  }
  public static void DblClick(IntPtr h, int x, int y) {
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(180);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    for (int i = 0; i < 2; i++) { mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(40); mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(70); }
    System.Threading.Thread.Sleep(400);
  }
}
'@
$null = [W9]::SetProcessDPIAware()
function Shot([string]$p) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  L "shot $p"
}
function GetConsoleText([System.Windows.Automation.AutomationElement]$ae) {
  $eCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
  $edits = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $eCond)
  $best = $null; $bestArea = 0
  foreach ($e in $edits) {
    $r = $e.Current.BoundingRectangle
    $area = $r.Width * $r.Height
    if ($area -gt $bestArea -and $r.Height -gt 40) { $bestArea = $area; $best = $e }
  }
  if (-not $best) { return '' }
  try { return $best.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value } catch { return '' }
}
$js = Join-Path $PdsBin 'cdt_js.exe'; $dbg = Join-Path $PdsBin 'cdt_dbg.exe'
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | ForEach-Object { L "kill leftover $($_.ProcessName) $($_.Id)"; Stop-Process -Id $_.Id -Force }
Start-Sleep -Seconds 2
$jsOut = Join-Path $OutDir 'jtagserver.log'
if (Test-Path $jsOut) { Remove-Item $jsOut -Force }
$null = Start-Process -FilePath $js -ArgumentList @('-work_dir', $OutDir) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError (Join-Path $OutDir 'jtagserver.err')
$port = $null
for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; $t = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue; if ($t -and $t -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break } }
if (-not $port) { L 'FAILED to get port'; exit 1 }
L "port=$port"
$sf = $Sbit -replace '\\', '/'; $df = $DprjIn -replace '\\', '/'
$tcl = "dbg_connect -ip 127.0.0.1 -port $port`r`ndbg_scan_chain`r`ndbg_program -device 0 -file $sf`r`ndbg_open_project -file $df`r`ndbg_add_all_to_waveform`r`n"
$tclPath = Join-Path $OutDir 'gui_session.tcl'
Set-Content -Path $tclPath -Value $tcl -Encoding ASCII
$dbgOut = Join-Path $OutDir 'debugger_stdout.log'
if (Test-Path $dbgOut) { Remove-Item $dbgOut -Force }
$cli = Start-Process -FilePath $dbg -ArgumentList @('-file', ($tclPath -replace '\\', '/')) -WorkingDirectory (Join-Path $OutDir 'debugger_log') -PassThru -RedirectStandardOutput $dbgOut -RedirectStandardError (Join-Path $OutDir 'debugger_stderr.log')
$mypid = [uint32]$cli.Id
L "cdt_dbg pid=$($cli.Id)"
Start-Sleep -Seconds 16
$main = [W9]::List($mypid) | Where-Object { $_.Vis -and $_.Title -match 'Fabric Debugger' } | Sort-Object { $_.W * $_.Ht } -Descending | Select-Object -First 1
if (-not $main) { L 'main window not found'; Shot (Join-Path $OutDir '70_nomain.png'); exit 2 }
$null = [W9]::ShowWindow($main.H, 9); $null = [W9]::MoveWindow($main.H, 40, 30, 1560, 980, $true)
Start-Sleep -Milliseconds 500
$null = [W9]::SetForegroundWindow($main.H); Start-Sleep -Milliseconds 500
$ae = [System.Windows.Automation.AutomationElement]::FromHandle($main.H)
L "main h=$($main.H)"
Shot (Join-Path $OutDir '71_ready.png')
$diCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
$bCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
# 1) enable match unit if the status cell says disabled
$items = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
$statusCell = $items | Where-Object { $_.Current.Name -match 'disabled|enabled' } | Select-Object -First 1
if ($statusCell -and $statusCell.Current.Name -ne 'enabled') {
  $sr = $statusCell.Current.BoundingRectangle
  L "status cell='$($statusCell.Current.Name)' rect=$sr -> double-click to toggle"
  [W9]::DblClick($main.H, [int]($sr.X + $sr.Width/2), [int]($sr.Y + $sr.Height/2))
  Start-Sleep -Milliseconds 800
  $items = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
  $sc2 = $items | Where-Object { $_.Current.Name -match 'disabled|enabled' } | Select-Object -First 1
  L "status now='$($sc2.Current.Name)'"
  Shot (Join-Path $OutDir '72_after_enable.png')
} else { L "status cell: '$($statusCell.Current.Name)'" }
# 2) set match-unit value
$enc = (Get-Content (Join-Path $ScriptsDir 'trigger_values.txt') | Where-Object { $_ -match "^${Orientation}_" }) -replace "^${Orientation}_[^=]*=", ''
$grp = ($enc -split '(.{4})' | Where-Object { $_ }) -join '_'
L "orientation=$Orientation len=$($enc.Length) grpLen=$($grp.Length)"
$items = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
$valCell = $items | Where-Object { $_.Current.Name -match '^[X01]{4}(_[X01]{4})+$' -and $_.Current.Name.Length -gt 200 } | Select-Object -First 1
if (-not $valCell) { L 'value cell not found'; foreach ($d in $items) { L "  cell '$($d.Current.Name)'" }; Shot (Join-Path $OutDir '73_noval.png'); exit 3 }
$r = $valCell.Current.BoundingRectangle
[W9]::DblClick($main.H, [int]($r.X + $r.Width - 40), [int]($r.Y + $r.Height/2))
Set-Clipboard -Value $grp; Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('^v'); Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 600
$items = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
$vc = $items | Where-Object { $_.Current.Name.Length -gt 200 } | Select-Object -First 1
L "value cell now len=$($vc.Current.Name.Length) tail=$($vc.Current.Name.Substring($vc.Current.Name.Length-30))"
Shot (Join-Path $OutDir '74_value_set.png')
# 3) click Run, poll console
$btns = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bCond)
$run = $btns | Where-Object { $_.Current.Name -eq 'Run' } | Select-Object -First 1
$rr = $run.Current.BoundingRectangle
[W9]::Click($main.H, [int]($rr.X + $rr.Width/2), [int]($rr.Y + $rr.Height/2))
L 'clicked Run'
$triggered = $false; $waited = 0
while ($waited -lt $WaitTriggerSec) {
  Start-Sleep -Seconds 1; $waited++
  if ($cli.HasExited) { L 'process exited while waiting'; break }
  $ct = GetConsoleText $ae
  if ($ct -match 'trigger successful') { $triggered = $true; L "TRIGGER SUCCESS after ${waited}s"; break }
  if ($ct -match 'stopped by user|exec unsuccessfully') { $tailTxt = ($ct -split "`n" | Select-Object -Last 3) -join ' | '; L "RUN FAILED after ${waited}s: $tailTxt"; break }
}
if (-not $triggered) { L "NOT TRIGGERED within ${WaitTriggerSec}s"; Shot (Join-Path $OutDir '75_not_triggered.png') }
else {
  Shot (Join-Path $OutDir '76_triggered_waveform.png')
  # 4) stop, save project, export ASCII
  $btns = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bCond)
  $stop = $btns | Where-Object { $_.Current.Name -match 'Stop' } | Select-Object -First 1
  if ($stop) { $sr = $stop.Current.BoundingRectangle; [W9]::Click($main.H, [int]($sr.X + $sr.Width/2), [int]($sr.Y + $sr.Height/2)); L 'clicked Stop'; Start-Sleep -Seconds 1 }
  # File -> Export Sample Data
  $miCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuItem)
  $mi = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)
  $file = $mi | Where-Object { $_.Current.Name -eq 'File' } | Select-Object -First 1
  if ($file) { $fr = $file.Current.BoundingRectangle; [W9]::Click($main.H, [int]($fr.X + $fr.Width/2), [int]($fr.Y + $fr.Height/2)); Start-Sleep -Milliseconds 800 }
  $mi2 = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)
  $exp = $mi2 | Where-Object { $_.Current.Name -eq 'Export Sample Data' } | Select-Object -First 1
  if ($exp) { $er = $exp.Current.BoundingRectangle; [W9]::Click($main.H, [int]($er.X + $er.Width/2), [int]($er.Y + $er.Height/2)); Start-Sleep -Seconds 2; L 'opened Export dialog' }
  else { L 'export item not found'; Shot (Join-Path $OutDir '77_no_export_item.png') }
}
L 'phase6 done'
