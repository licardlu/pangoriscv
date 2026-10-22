# watch_pnr.ps1 -- sample CPU / GPU / NPU / memory while PDS place-and-route runs.
#
# Why: "routing does not converge" is routinely blamed on the machine.  The
# measurement that settles it is *cores actually used by pds_shell*: if that
# number is ~1.2 out of N, the flow is single-threaded and a bigger machine buys
# nothing.  Pango's router is single-threaded on this device
# (`-number_of_router_thread` is rejected with Flow-0182), and the only way to
# run seeds in parallel is `-parallel`, which needs one fabric license per seed.
#
# Usage (from firmware/code):
#   powershell -ExecutionPolicy Bypass -File tools\watch_pnr.ps1 -Minutes 120 -Out build\cpu_watch.csv
#
# Columns: ts, cpu_total_pct, pds_cores, gpu_pct, npu_pct, pds_mem_mb, cpu_mem_mb
# ASCII only: Windows PowerShell 5.1 decodes .ps1 with the ANSI code page.
param(
  [int]$Minutes = 120,
  [int]$IntervalSec = 5,
  [string]$Out = 'cpu_watch.csv'
)

$ErrorActionPreference = 'Continue'

function Get-Total($path) {
  # sum every instance of a counter; returns $null when the counter is absent
  try {
    $s = (Get-Counter -Counter $path -ErrorAction Stop).CounterSamples
    $sum = ($s | Measure-Object -Property CookedValue -Sum).Sum
    if ($null -eq $sum) { return $null }
    return [math]::Round($sum, 1)
  } catch { return $null }
}

$gpuOk = $true
$npuOk = $true
try { (Get-Counter -ListSet 'GPU Engine' -ErrorAction Stop) | Out-Null } catch { $gpuOk = $false }
try { (Get-Counter -ListSet 'NPU Engine' -ErrorAction Stop) | Out-Null } catch { $npuOk = $false }

"ts,cpu_total_pct,pds_cores,gpu_pct,npu_pct,pds_mem_mb,cpu_mem_mb" |
  Set-Content -Encoding ASCII $Out

$prevPds = $null
$n = [int]($Minutes * 60 / $IntervalSec)
for ($i = 0; $i -lt $n; $i++) {
  Start-Sleep -Seconds $IntervalSec
  $now = Get-Date

  $cpuTotal = Get-Total '\Processor(_Total)\% Processor Time'
  if ($null -eq $cpuTotal) { $cpuTotal = (Get-CimInstance Win32_Processor |
      Measure-Object -Property LoadPercentage -Average).Average }

  $pds = @(Get-Process -Name pds_shell -ErrorAction SilentlyContinue)
  $pdsCpu = 0; $pdsMem = 0
  if ($pds.Count -gt 0) {
    $pdsCpu = ($pds | Measure-Object -Property CPU -Sum).Sum
    $pdsMem = [math]::Round((($pds | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB, 0)
  }
  $cores = 0
  if ($null -ne $prevPds) {
    $cores = [math]::Round(($pdsCpu - $prevPds) / $IntervalSec, 2)
  }
  $prevPds = $pdsCpu

  $gpu = if ($gpuOk) { Get-Total '\GPU Engine(*)\Utilization Percentage' } else { $null }
  $npu = if ($npuOk) { Get-Total '\NPU Engine(*)\Utilization Percentage' } else { $null }
  if ($null -eq $gpu) { $gpu = 'NA' }
  if ($null -eq $npu) { $npu = 'NA' }

  $os = Get-CimInstance Win32_OperatingSystem
  $cpuMem = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024, 0)

  "{0:HH:mm:ss},{1},{2},{3},{4},{5},{6}" -f $now, $cpuTotal, $cores, $gpu, $npu, $pdsMem, $cpuMem |
    Add-Content -Encoding ASCII $Out
}
Write-Output "watch_pnr done -> $Out"
