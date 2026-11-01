# gui_trigger_phase1.ps1 -- start JtagServer+Fabric Debugger with a project, dismiss modal
# dialogs, move the main window on-screen, screenshot. Leaves both processes alive.
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$PdsBin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin',
  [string]$Dprj = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\logs\ila_capture_encA3\ila_capture.dprj',
  [string]$Sbit = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila_debug\src\build\pango_native\generate_bitstream\pangoriscv_top.sbit'
)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$log = Join-Path $OutDir 'gui_trigger_phase1.log'
function L([string]$m) { $ts = (Get-Date).ToString('HH:mm:ss'); "$ts $m" | Tee-Object -FilePath $log -Append }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class W3 {
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
  public static List<WinInfo> List() {
    var list = new List<WinInfo>();
    EnumWindows((h,l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      var sb = new StringBuilder(512); GetClassName(h, sb, 512);
      var tb = new StringBuilder(512); GetWindowText(h, tb, 512);
      RECT r; GetWindowRect(h, out r);
      var w = new WinInfo{H=h,Pid=pid,Cls=sb.ToString(),Title=tb.ToString(),X=r.L,Y=r.T,W=r.R-r.L,Ht=r.B-r.T,Vis=IsWindowVisible(h)};
      list.Add(w); return true;
    }, IntPtr.Zero);
    return list;
  }
}
'@
$null = [W3]::SetProcessDPIAware()
function Shot([string]$p) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  L "shot $p"
}
$js = Join-Path $PdsBin 'cdt_js.exe'; $dbg = Join-Path $PdsBin 'cdt_dbg.exe'
Get-Process cdt_js,cdt_dbg -ErrorAction SilentlyContinue | ForEach-Object { L "kill leftover $($_.ProcessName) $($_.Id)"; Stop-Process -Id $_.Id -Force }
Start-Sleep -Seconds 2
$jsOut = Join-Path $OutDir 'jtagserver.log'
if (Test-Path $jsOut) { Remove-Item $jsOut -Force }
L 'start JtagServer'
$srv = Start-Process -FilePath $js -ArgumentList @('-work_dir', $OutDir) -PassThru -RedirectStandardOutput $jsOut -RedirectStandardError (Join-Path $OutDir 'jtagserver.err')
$port = $null
for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; $t = Get-Content $jsOut -Raw -ErrorAction SilentlyContinue; if ($t -and $t -match 'use port\s*:\s*(\d+)') { $port = $Matches[1]; break } }
if (-not $port) { L 'FAILED to get port'; exit 1 }
L "port=$port"
$sf = $Sbit -replace '\\', '/'; $df = $Dprj -replace '\\', '/'
$tcl = "dbg_connect -ip 127.0.0.1 -port $port`r`ndbg_scan_chain`r`ndbg_program -device 0 -file $sf`r`ndbg_open_project -file $df`r`ndbg_add_all_to_waveform`r`ndbg_delay -time 600`r`ndbg_close`r`n"
$tclPath = Join-Path $OutDir 'gui_session.tcl'
Set-Content -Path $tclPath -Value $tcl -Encoding ASCII
$dbgOut = Join-Path $OutDir 'debugger_stdout.log'
if (Test-Path $dbgOut) { Remove-Item $dbgOut -Force }
L 'start cdt_dbg'
$cli = Start-Process -FilePath $dbg -ArgumentList @('-file', ($tclPath -replace '\\', '/')) -WorkingDirectory (Join-Path $OutDir 'debugger_log') -PassThru -RedirectStandardOutput $dbgOut -RedirectStandardError (Join-Path $OutDir 'debugger_stderr.log')
L "cdt_dbg pid=$($cli.Id)"
Start-Sleep -Seconds 20
# enumerate windows of this pid, dismiss any modal dialog
$mypid = [uint32]$cli.Id
for ($round = 0; $round -lt 6; $round++) {
  $wins = [W3]::List() | Where-Object { $_.Pid -eq $mypid -and $_.Vis -and $_.W -gt 20 -and $_.Ht -gt 20 }
  foreach ($w in $wins) { L ("win round=$round h=$($w.H) class='$($w.Cls)' title='$($w.Title)' rect=$($w.X),$($w.Y),$($w.W),$($w.Ht)") }
  $dlg = $wins | Where-Object { $_.Cls -ne 'dbgMainWindow' -and ($_.Cls -match 'QMessageBox|Dialog|#32770|Tool' -or $_.Title -match 'Expiration|Reminder|Warning|Error|License|提醒|过期') } | Select-Object -First 1
  if (-not $dlg) { L 'no modal dialog found'; break }
  L "dismiss dialog class='$($dlg.Cls)' title='$($dlg.Title)'"
  $null = [W3]::ShowWindow($dlg.H, 9)
  $null = [W3]::SetForegroundWindow($dlg.H)
  Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
  Start-Sleep -Milliseconds 800
}
$main = [W3]::List() | Where-Object { $_.Pid -eq $mypid -and $_.Cls -eq 'dbgMainWindow' } | Select-Object -First 1
if (-not $main) { L 'main window NOT found'; Shot (Join-Path $OutDir '20_nomain.png'); exit 2 }
L "main h=$($main.H) rect=$($main.X),$($main.Y),$($main.W),$($main.Ht)"
$null = [W3]::ShowWindow($main.H, 9)
$null = [W3]::MoveWindow($main.H, 80, 50, 1500, 950, $true)
Start-Sleep -Milliseconds 600
$null = [W3]::SetForegroundWindow($main.H)
Start-Sleep -Milliseconds 800
$m2 = [W3]::List() | Where-Object { $_.H -eq $main.H } | Select-Object -First 1
L "main moved rect=$($m2.X),$($m2.Y),$($m2.W),$($m2.Ht)"
Shot (Join-Path $OutDir '21_setup.png')
L 'phase1 DONE (processes left alive)'
