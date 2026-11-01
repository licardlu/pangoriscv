# gui_trigger_phase2.ps1 -- relaunch debugger with project (no long delay), move window,
# set match-unit value via GUI cell editor + clipboard, then dbg_run an immediate capture.
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$Dprj  = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\logs\ila_capture_encA3\ila_capture.dprj',
  [string]$Sbit  = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila_debug\src\build\pango_native\generate_bitstream\pangoriscv_top.sbit',
  [string]$TriggerValues = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\trigger_values.txt'
)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$log = Join-Path $OutDir 'gui_trigger_phase2.log'
function L([string]$m) { $ts = (Get-Date).ToString('HH:mm:ss'); "$ts $m" | Tee-Object -FilePath $log -Append }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class W4 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int cx, int cy, bool repaint);
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
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(150);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(60);
    mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(150);
  }
  public static void DblClick(IntPtr h, int x, int y) {
    ShowWindow(h, 9); SetForegroundWindow(h); System.Threading.Thread.Sleep(150);
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    for (int i = 0; i < 2; i++) { mouse_event(0x0002,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(40); mouse_event(0x0004,0,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(60); }
    System.Threading.Thread.Sleep(300);
  }
}
'@
$null = [W4]::SetProcessDPIAware()
function Shot([string]$p) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  L "shot $p"
}
$js = Join-Path $PdsBin 'cdt_js.exe'; $dbg = Join-Path $PdsBin 'cdt_dbg.exe'
Get-Process cdt_dbg -ErrorAction SilentlyContinue | ForEach-Object { L "kill stale cdt_dbg $($_.Id)"; Stop-Process -Id $_.Id -Force }
Start-Sleep -Seconds 2
$jsOut = Join-Path $OutDir 'jtagserver.log'
$port = $null
$t = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue
if ($t -and $t -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; L "reuse running jtagserver port=$port" }
if (-not $port) {
  if (Test-Path $jsOut) { Remove-Item $jsOut -Force }
  $null = Start-Process -FilePath $js -ArgumentList @('-work_dir', $OutDir) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError (Join-Path $OutDir 'jtagserver.err')
  for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; $t = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue; if ($t -and $t -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break } }
}
if (-not $port) { L 'FAILED to get port'; exit 1 }
L "port=$port"
$sf = $Sbit -replace '\\', '/'; $df = $Dprj -replace '\\', '/'
$tcl = "dbg_connect -ip 127.0.0.1 -port $port`r`ndbg_scan_chain`r`ndbg_program -device 0 -file $sf`r`ndbg_open_project -file $df`r`ndbg_add_all_to_waveform`r`n"
$tclPath = Join-Path $OutDir 'gui_session2.tcl'
Set-Content -Path $tclPath -Value $tcl -Encoding ASCII
$dbgOut = Join-Path $OutDir 'debugger_stdout.log'
if (Test-Path $dbgOut) { Remove-Item $dbgOut -Force }
L 'start cdt_dbg (no long delay at end)'
$cli = Start-Process -FilePath $dbg -ArgumentList @('-file', ($tclPath -replace '\\', '/')) -WorkingDirectory (Join-Path $OutDir 'debugger_log') -PassThru -RedirectStandardOutput $dbgOut -RedirectStandardError (Join-Path $OutDir 'debugger_stderr.log')
$mypid = [uint32]$cli.Id
L "cdt_dbg pid=$($cli.Id)"
Start-Sleep -Seconds 16
# find main window by title
$main = [W4]::List($mypid) | Where-Object { $_.Vis -and $_.W -gt 200 -and $_.Ht -gt 200 -and $_.Title -match 'Fabric Debugger' } | Sort-Object { $_.W * $_.Ht } -Descending | Select-Object -First 1
if (-not $main) { L 'main window NOT found'; [W4]::List(0) | Where-Object { $_.Pid -eq $mypid } | ForEach-Object { L "win class='$($_.Cls)' title='$($_.Title)' vis=$($_.Vis) rect=$($_.X),$($_.Y),$($_.W),$($_.Ht)" }; Shot (Join-Path $OutDir '30_nomain2.png'); exit 2 }
L "main h=$($main.H) title='$($main.Title)' rect=$($main.X),$($main.Y),$($main.W),$($main.Ht)"
$null = [W4]::ShowWindow($main.H, 9)
$null = [W4]::MoveWindow($main.H, 40, 30, 1560, 980, $true)
Start-Sleep -Milliseconds 800
$null = [W4]::SetForegroundWindow($main.H)
Start-Sleep -Milliseconds 800
$m2 = [W4]::List($mypid) | Where-Object { $_.H -eq $main.H } | Select-Object -First 1
L "main moved rect=$($m2.X),$($m2.Y),$($m2.W),$($m2.Ht)"
Shot (Join-Path $OutDir '31_moved.png')
# read console log tail
L '--- debugger stdout tail ---'
Get-Content $dbgOut -ErrorAction SilentlyContinue | Select-Object -Last 8 | ForEach-Object { L "  $_" }
L 'phase2 setup done'
