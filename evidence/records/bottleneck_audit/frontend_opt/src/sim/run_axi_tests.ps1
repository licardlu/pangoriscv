param(
    [int[]]$Seeds = (1..20),
    [string]$ModelSimPath = 'E:\donwload\win64',
    [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runRoot = Join-Path $root ('.sim_runs\t01-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
Write-Output "RUN_DIR $runRoot"
if ($Seeds.Count -eq 0 -or ($Seeds | Where-Object { $_ -le 0 }).Count -gt 0) {
    throw 'Use at least one positive seed'
}
if ($TimeoutSeconds -le 0) { throw 'TimeoutSeconds must be positive' }

function Invoke-ModelSim([string]$Tool, [string[]]$Arguments, [string]$LogName) {
    $exe = Join-Path $ModelSimPath ($Tool + '.exe')
    if (!(Test-Path -LiteralPath $exe)) { throw "Missing tool $exe" }
    $stdout = Join-Path $runRoot ($LogName + '.stdout')
    $stderr = Join-Path $runRoot ($LogName + '.stderr')
    $log = Join-Path $runRoot ($LogName + '.log')
    # All values are local filesystem paths, not shell code.
    $quoted = $Arguments | ForEach-Object {
        if ($_ -match '"') { throw 'Embedded quotes are not supported' }
        '"' + $_ + '"'
    }
    $process = Start-Process -FilePath $exe -ArgumentList $quoted `
        -WorkingDirectory $runRoot -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        if (!$process.WaitForExit(10000)) { throw "TIMEOUT cleanup failed $LogName" }
        throw "TIMEOUT $LogName; evidence $runRoot"
    }
    $process.Refresh()
    $text = [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)
    [IO.File]::WriteAllText($log, $text)
    return @{ Code=$process.ExitCode; Text=$text; Log=$log }
}

function Assert-Command($Result) {
    if ($Result.Code -ne 0 -or $Result.Text -match '\*\*\s*(Error|Fatal)') {
        throw "COMMAND_FAIL $($Result.Log)"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'axi_sources.f')
$sources = @($manifest | Where-Object { $_.Trim() -and !$_.Trim().StartsWith('#') } |
    ForEach-Object {
        $source = Join-Path $root $_.Trim()
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing $source" }
        $source
    })
if ($sources.Count -eq 0) { throw 'Empty AXI source manifest' }
Assert-Command (Invoke-ModelSim 'vlib' @('work') 'vlib')
Assert-Command (Invoke-ModelSim 'vlog' (@('-sv','-work','work') + $sources) 'compile')
$script = "onerror {quit -f -code 1}`nrun -all`nquit -f -code 0`n"
[IO.File]::WriteAllText((Join-Path $runRoot 'run.do'), $script)
$negative = Invoke-ModelSim 'vsim' @('-c','-onfinish','stop',
    'work.tb_axi_memory','+SEED=1','+INJECT=1','-do','run.do') 'negative'
if ($negative.Text -notmatch 'AXI_MONITOR AR_STABILITY' -or
    $negative.Text -match 'TEST_PASS|INJECTION_NOT_DETECTED' -or
    $negative.Text -notmatch '\*\*\s*Fatal') {
    throw "NEGATIVE_NOT_VERIFIED $($negative.Log)"
}
Write-Output 'EXPECTED_FAILURE AR_STABILITY'
foreach ($seed in $Seeds) {
    $result = Invoke-ModelSim 'vsim' @('-c','-onfinish','stop',
        'work.tb_axi_memory',"+SEED=$seed",'+INJECT=0','-do','run.do') "seed-$seed"
    Assert-Command $result
    $passes = [regex]::Matches($result.Text, 'TEST_PASS T01 seed=').Count
    if ($passes -ne 1 -or $result.Text -match 'TEST_FAIL|TIMEOUT|Time\s*Out' -or
        $result.Text -notmatch "TEST_PASS T01 seed=$seed\b") {
        throw "TEST_FAIL_OR_NO_PASS $($result.Log)"
    }
    Write-Output "PASS seed=$seed"
}
Write-Output "SUMMARY $($Seeds.Count) / $($Seeds.Count) PASS; negative=detected"
