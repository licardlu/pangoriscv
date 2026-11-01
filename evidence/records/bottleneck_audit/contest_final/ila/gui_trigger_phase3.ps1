# gui_trigger_phase3.ps1 -- set match-unit value in GUI Trigger Setup (clipboard paste), then
# dbg_run / dbg_stop / dbg_save_project through the Tcl console input, leaving GUI alive.
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$TriggerValues = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\trigger_values.txt',
  [string]$DprjOut = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\logs\ila_gui_trigger\ila_capture_encA4.dprj'
)
$ErrorActionPreference = 'Continue'
$log = Join-Path $OutDir 'gui_trigger_phase3.log'
function L([string]$m) { $ts = (Get-Date).ToString('HH:mm:ss'); "$ts $m" | Tee-Object -FilePath $log -Append }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class W5 {
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
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(200);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(150);
    mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(70);
    mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(200);
  }
  public static void DblClick(IntPtr h, int x, int y) {
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(200);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(150);
    for (int i = 0; i < 2; i++) { mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(40); mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(70); }
    System.Threading.Thread.Sleep(400);
  }
}
'@
$null = [W5]::SetProcessDPIAware()
function Shot([string]$p) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  L "shot $p"
}
$p = Get-Process cdt_dbg -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { L 'no cdt_dbg'; exit 1 }
$mypid = [uint32]$p.Id
$main = [W5]::List($mypid) | Where-Object { $_.Vis -and $_.Title -match 'Fabric Debugger' } | Sort-Object { $_.W * $_.Ht } -Descending | Select-Object -First 1
if (-not $main) { L 'main window not found'; exit 2 }
L "main h=$($main.H) rect=$($main.X),$($main.Y),$($main.W),$($main.Ht)"
$ae = [System.Windows.Automation.AutomationElement]::FromHandle($main.H)
if (-not $ae) { L 'FromHandle failed'; exit 2 }
L "uia name='$($ae.Current.Name)' class='$($ae.Current.ClassName)'"
Shot (Join-Path $OutDir '40_before_edit.png')
# locate value DataItem
$diCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
$items = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
L "dataitems=$($items.Count)"
$valCell = $null
foreach ($d in $items) { $n = $d.Current.Name; if ($n -match '^X{4}(_X{4})+$') { $valCell = $d; break } }
if (-not $valCell) { L 'value cell not found'; foreach ($d in $items) { L "  item '$($d.Current.Name)'" }; exit 3 }
$r = $valCell.Current.BoundingRectangle
L "value cell rect=$r namelen=$($valCell.Current.Name.Length)"
$cx = [int]($r.X + $r.Width - 40); $cy = [int]($r.Y + $r.Height/2)
[W5]::DblClick($main.H, $cx, $cy)
Shot (Join-Path $OutDir '41_editor_open.png')
$encA = (Get-Content $TriggerValues | Where-Object { $_ -match '^encA_ch0_rightmost=' }) -replace '^encA_ch0_rightmost=',''
$grpA = ($encA -split '(.{4})' | Where-Object { $_ }) -join '_'
L "grpA len=$($grpA.Length)"
try { Set-Clipboard -Value $grpA; L 'clipboard set' } catch { L "Set-Clipboard failed: $_" ; [System.Windows.Forms.Clipboard]::SetText($grpA); L 'winforms clipboard set' }
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('^v'); Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 800
Shot (Join-Path $OutDir '42_after_value.png')
# read dataitem names again looking for a grouped value with 0/1 pattern
$items2 = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
foreach ($d in $items2) { $n = $d.Current.Name; if ($n.Length -gt 60) { L "CELL len=$($n.Length) head=$($n.Substring(0,20)) tail=$($n.Substring($n.Length-24))" } }
# console input: find edit controls, pick bottom-most
$eCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
$edits = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $eCond)
$best = $null
foreach ($e in $edits) {
  $rr = $e.Current.BoundingRectangle
  L "edit rect=$rr name='$($e.Current.Name)'"
  if ($rr.Height -gt 10 -and $rr.Width -gt 300) { if (-not $best -or $rr.Y -gt $best.Y) { $best = $rr } }
}
if (-not $best) { L 'no console edit found'; exit 4 }
L "console edit rect=$best"
$null = [W5]::SetForegroundWindow($main.H)
$null = [W5]::SetCursorPos([int]($best.X + 60), [int]($best.Y + $best.Height/2))
Start-Sleep -Milliseconds 300
[W5]::Click($main.H, [int]($best.X + 60), [int]($best.Y + $best.Height/2))
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait('dbg_run{ENTER}')
L 'sent dbg_run; waiting 4s'
Start-Sleep -Seconds 4
Shot (Join-Path $OutDir '43_after_run.png')
[System.Windows.Forms.SendKeys]::SendWait('dbg_stop{ENTER}')
Start-Sleep -Seconds 1
[System.Windows.Forms.SendKeys]::SendWait("dbg_save_project -file $($DprjOut -replace '\\','/'){ENTER}")
Start-Sleep -Seconds 2
Shot (Join-Path $OutDir '44_after_save.png')
Get-Content (Join-Path $OutDir 'debugger_stdout.log') -ErrorAction SilentlyContinue | Select-Object -Last 12 | ForEach-Object { L "  stdout: $_" }
L 'phase3 done'
