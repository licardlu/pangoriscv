# gen_contest_results.ps1 -- machine-generate the 600-iteration A/B results table
# from the raw UART captures and the archived bitstreams (single source of truth).
# ASCII only (Windows PowerShell 5.1 parses .ps1 in the ANSI codepage).
$ErrorActionPreference = 'Stop'
$A    = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$cf   = Join-Path $A 'contest_final\src'
$b0   = Join-Path $A 'baseline_build\src'
$ph2  = Join-Path $A 'board\phase2'
$outCsv = Join-Path $A 'results\contest_final_600iter_ab.csv'
$cpuHz  = 27000000

$runs = @(
  @{ id='cand_perf600_run1'; ver='T4+LSU candidate'; mode='performance'; seed='0x0/0x0/0x66'; img='performance'; run='cand_perf600_run1'; tree=$cf },
  @{ id='cand_perf600_run2'; ver='T4+LSU candidate'; mode='performance'; seed='0x0/0x0/0x66'; img='performance'; run='cand_perf600_run2'; tree=$cf },
  @{ id='b0_perf600_run1';   ver='B0 baseline';      mode='performance'; seed='0x0/0x0/0x66'; img='performance'; run='b0_perf600_run1';   tree=$b0 },
  @{ id='b0_perf600_run2';   ver='B0 baseline';      mode='performance'; seed='0x0/0x0/0x66'; img='performance'; run='b0_perf600_run2';   tree=$b0 },
  @{ id='val_cand_run1';     ver='T4+LSU candidate'; mode='validation';  seed='0x3415/0x3415/0x66'; img='validation'; run='val_cand_run1'; tree=$cf },
  @{ id='val_cand_run2';     ver='T4+LSU candidate'; mode='validation';  seed='0x3415/0x3415/0x66'; img='validation'; run='val_cand_run2'; tree=$cf },
  @{ id='val_b0_run1';       ver='B0 baseline';      mode='validation';  seed='0x3415/0x3415/0x66'; img='validation'; run='val_b0_run1';   tree=$b0 },
  @{ id='val_b0_run2';       ver='B0 baseline';      mode='validation';  seed='0x3415/0x3415/0x66'; img='validation'; run='val_b0_run2';   tree=$b0 }
)

$rows = @()
foreach ($r in $runs) {
  $u = Join-Path $ph2 ($r.run + '.txt')
  if (-not (Test-Path $u)) { throw "missing UART capture $u" }
  $t = Get-Content $u -Raw
  function Grab([string]$pat) { $m = [regex]::Match($t, $pat); if (-not $m.Success) { return '' }; return $m.Groups[1].Value.Trim() }
  $ticks   = [int64](Grab 'Total ticks\s*:\s*(\d+)')
  $secs    = Grab 'Total time \(secs\)\s*:\s*(\d+)'
  $iters   = Grab 'Iterations\s*:\s*(\d+)'
  $itersec = Grab 'Iterations/Sec\s*:\s*(\d+)'
  $seedcrc = Grab 'seedcrc\s*:\s*(\S+)'
  $crclist = Grab '\[0\]crclist\s*:\s*(\S+)'
  $crcmat  = Grab '\[0\]crcmatrix\s*:\s*(\S+)'
  $crcst   = Grab '\[0\]crcstate\s*:\s*(\S+)'
  $crcfin  = Grab '\[0\]crcfinal\s*:\s*(\S+)'
  $valid   = if ($t -match 'Correct operation validated') { 'VALID' } elseif ($t -match 'Errors detected') { 'INVALID' } else { 'UNKNOWN' }

  $tag = if ($r.mode -eq 'performance') { 'pango_native-perf600' } else { 'pango_native-val600' }
  $runDir = Join-Path $r.tree ("build\" + $tag)
  $sbit = Join-Path $runDir 'generate_bitstream\pangoriscv_top.sbit'
  $prog = Join-Path $runDir 'program.hex'
  $data = Join-Path $runDir 'data.hex'
  $sbitSha = (Get-FileHash $sbit -Algorithm SHA256).Hash
  $progSha = (Get-FileHash $prog -Algorithm SHA256).Hash
  $dataSha = (Get-FileHash $data -Algorithm SHA256).Hash
  $capSha  = (Get-FileHash $u -Algorithm SHA256).Hash
  $cmPerMHz = [math]::Round(([double]$iters * 1e6) / [double]$ticks, 4)
  $coremark = [math]::Round(([double]$iters * $cpuHz) / [double]$ticks, 3)
  $rows += [pscustomobject][ordered]@{
    run_id = $r.id; version = $r.ver; mode = $r.mode; seed_config = $r.seed
    iterations = $iters; cpu_hz = $cpuHz
    total_ticks = $ticks; cpm_ticks_hi_lo = (Grab 'CPM_TICKS hi=\S+ lo=(\d+)')
    time_secs = $secs; iterations_per_sec = $itersec
    coremark_per_mhz = $cmPerMHz; coremark = $coremark
    seedcrc = $seedcrc; crclist = $crclist; crcmatrix = $crcmat; crcstate = $crcst; crcfinal = $crcfin
    validated = $valid
    uart_capture = ('board/phase2/' + $r.run + '.txt'); uart_sha256 = $capSha
    program_hex_sha256 = $progSha; data_hex_sha256 = $dataSha; bitstream_sha256 = $sbitSha
    bitstream = ('build/' + $tag + '/generate_bitstream/pangoriscv_top.sbit')
  }
}
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8
Write-Host "wrote $outCsv ($($rows.Count) rows)"
$rows | ForEach-Object {
  '{0,-18} {1,-17} {2,-11} ticks={3,12} t={4,2}s cm/mhz={5,7} coremark={6,8} crcfinal={7} {8}' -f $_.run_id,$_.version,$_.mode,$_.total_ticks,$_.time_secs,$_.coremark_per_mhz,$_.coremark,$_.crcfinal,$_.validated
}
$cp = $rows | Where-Object { $_.mode -eq 'performance' -and $_.run_id -like 'cand*' } | Select-Object -First 1
$bp = $rows | Where-Object { $_.mode -eq 'performance' -and $_.run_id -like 'b0*' }   | Select-Object -First 1
$cv = $rows | Where-Object { $_.mode -eq 'validation'  -and $_.run_id -like 'cand*' } | Select-Object -First 1
$bv = $rows | Where-Object { $_.mode -eq 'validation'  -and $_.run_id -like 'val_b0*'} | Select-Object -First 1
Write-Host ''
Write-Host ('perf: cand/b0 ticks = {0} / {1}, ratio = {2:N6}, time reduction = {3:N2}%' -f $cp.total_ticks,$bp.total_ticks,([double]$bp.total_ticks/$cp.total_ticks),(1-([double]$cp.total_ticks/$bp.total_ticks))*100)
Write-Host ('val : cand/b0 ticks = {0} / {1}, ratio = {2:N6}, time reduction = {3:N2}%' -f $cv.total_ticks,$bv.total_ticks,([double]$bv.total_ticks/$cv.total_ticks),(1-([double]$cv.total_ticks/$bv.total_ticks))*100)
