# Regression driver for the contest_candidate tree.
# Runs every simulation suite of this tree in one pass, keeps one log per
# suite and a summary table with the exit code and the last result lines.
# Usage:  pwsh -File tools/run_regression.ps1 -OutDir <dir> [-Only name1,name2]
param(
    [string]$OutDir = '',
    [string]$Only = ''
)
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($OutDir -eq '') { $OutDir = Join-Path $root ('.sim_runs\regression-' + [guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$env:PATH = 'E:\donwload\win64;' + $env:PATH

$suites = @(
    @{ name = 'unit';        script = 'sim/run_unit_tests.py';        args = @() },
    @{ name = 'engine';      script = 'sim/run_engine_tests.py';      args = @() },
    @{ name = 'ifu_engine';  script = 'sim/run_ifu_engine_tests.py';  args = @() },
    @{ name = 'dcache';      script = 'sim/run_dcache_tests.py';      args = @() },
    @{ name = 'icache';      script = 'sim/run_icache_tests.py';      args = @() },
    @{ name = 'interconnect';script = 'sim/run_interconnect_tests.py';args = @() },
    @{ name = 'predictor';   script = 'sim/run_predictor_tests.py';   args = @() },
    @{ name = 'pipeline';    script = 'sim/run_pipeline_tests.py';    args = @() },
    @{ name = 'ram';         script = 'sim/run_ram_tests.py';         args = @() },
    @{ name = 'gpio_trace';  script = 'sim/run_gpio_trace_tests.py';  args = @() },
    @{ name = 'perf';        script = 'sim/run_perf_tests.py';        args = @('--case', 'all') },
    @{ name = 'isa_e2e';     script = 'tools/run_isa_e2e.py';         args = @() },
    @{ name = 'halt_reset';  script = 'tools/run_halt_reset_tests.py';args = @() }
)
if ($Only -ne '') {
    $wanted = $Only.Split(',') | ForEach-Object { $_.Trim() }
    $suites = $suites | Where-Object { $wanted -contains $_.name }
}

$rows = @()
foreach ($s in $suites) {
    $log = Join-Path $OutDir ($s.name + '.log')
    $scriptPath = Join-Path $root $s.script
    Write-Output ("=== {0} : {1} ===" -f $s.name, $s.script)
    $started = Get-Date
    Push-Location $root
    $out = & python $scriptPath @($s.args) 2>&1
    $code = $LASTEXITCODE
    Pop-Location
    $text = ($out | Out-String)
    [IO.File]::WriteAllText($log, $text)
    $tail = ($text.Trim() -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 3) -join ' | '
    $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    $status = if ($code -eq 0) { 'PASS' } else { 'FAIL' }
    $rows += [pscustomobject]@{ suite = $s.name; exit = $code; status = $status; seconds = $elapsed; tail = $tail; log = $log }
    Write-Output ("RESULT {0} exit={1} {2}s :: {3}" -f $s.name, $code, $elapsed, $tail)
}

$rows | Format-Table -AutoSize | Out-String -Width 400 | Tee-Object -FilePath (Join-Path $OutDir 'summary.txt') | Write-Output
$fail = ($rows | Where-Object { $_.status -ne 'PASS' }).Count
Write-Output ("REGRESSION {0}: {1}/{2} suites passed, dir {3}" -f $(if ($fail -eq 0) { 'PASS' } else { 'FAIL' }), ($rows.Count - $fail), $rows.Count, $OutDir)
if ($fail -ne 0) { exit 1 }
