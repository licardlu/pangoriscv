$ErrorActionPreference = 'Continue'
$bin = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin'
$out = 'E:\file\pango\project\ai_lab\sim\flash_20261101'
$log = "$out\elevated.log"
"=== start $(Get-Date -Format o)" | Set-Content -Encoding utf8 $log
Get-Process cdt_js -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$srv = Start-Process -FilePath "$bin\cdt_js.exe" -ArgumentList @('-work_dir', $out) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$out\server2.log" -RedirectStandardError "$out\server2.err"
$port = $null
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 250
    $t = Get-Content "$out\server2.log" -Raw -ErrorAction SilentlyContinue
    if ($t -match 'use port\s*:\s*(\d+)') { $port = [int]$Matches[1]; break }
}
"port=$port" | Add-Content -Encoding utf8 $log
if (-not $port) { "NO_PORT" | Add-Content -Encoding utf8 $log; exit 1 }
& "$bin\cdt_cfg.exe" -file "$out\scan.tcl" -ip 127.0.0.1 -port $port -work_dir $out *> "$out\scan2.log"
"scan_rc=$LASTEXITCODE" | Add-Content -Encoding utf8 $log
Get-Content "$out\scan2.log" -ErrorAction SilentlyContinue | Add-Content -Encoding utf8 $log
