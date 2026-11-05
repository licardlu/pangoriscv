<#
    Offline smoke test for the application RTL layer.

    Runs three self-contained testbenches that need no camera, no DDR model and
    no stimulus files beyond the two UI hex tables that ship in assets/:

        servo_pwm4_tb          16 路按键/方向组合的四路舵机 PWM
        trash_peripherals_tb   答题-开盖-复位 闭环（按键、去抖、UI、语音事件）
        light_panel_tb         状态面板字符与精灵 ROM 边界

    All three must print "TEST_PASS ...". This proves the peripheral and UI RTL
    is self-consistent without touching hardware.

    Usage:
        powershell -ExecutionPolicy Bypass -File run_smoke.ps1
        powershell -ExecutionPolicy Bypass -File run_smoke.ps1 -ModelSim "D:/Modelism/win64"

    Exit code 0 = all three passed.
#>
param(
    [string]$ModelSim = '',
    [string]$WorkRoot = ''
)
$ErrorActionPreference = 'Stop'

$App = $PSScriptRoot
if ($ModelSim -eq '') {
    if ($env:MODELSIM_BIN) { $ModelSim = $env:MODELSIM_BIN }
    else { throw 'Pass -ModelSim <win64 dir> or set MODELSIM_BIN. No default is assumed: guessing a tool path is how people end up running the wrong simulator.' }
}
foreach ($tool in @('vlib.exe', 'vlog.exe', 'vsim.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModelSim $tool))) {
        throw "ModelSim tool not found: $tool under $ModelSim. Pass -ModelSim <win64 dir> or set MODELSIM_BIN."
    }
}
if ($WorkRoot -eq '') {
    $WorkRoot = Join-Path ([IO.Path]::GetTempPath()) ('qinghe_smoke_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
}
$null = New-Item -ItemType Directory -Path $WorkRoot -Force
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path

# Truncate the work library so a previous run cannot mask a compile error.
if (Test-Path -LiteralPath (Join-Path $WorkRoot 'work')) {
    Remove-Item -LiteralPath (Join-Path $WorkRoot 'work') -Recurse -Force
}

$Rtl = Join-Path $App 'rtl'
$Tests = Join-Path $App 'tests'
$Assets = Join-Path $App 'assets'

# light_panel_tb loads these by bare filename, i.e. from the current directory.
foreach ($hex in @('ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex')) {
    $source = Join-Path $Assets $hex
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing UI asset: $source" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $WorkRoot $hex) -Force
}

Push-Location $WorkRoot
$failures = @()
try {
    & (Join-Path $ModelSim 'vlib.exe') work | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }

    $cases = @(
        @{ Name = 'servo_pwm4_tb';
           Sources = @((Join-Path $Rtl 'servo_pwm4.sv'), (Join-Path $Tests 'servo_pwm4_tb.sv')) },
        @{ Name = 'trash_peripherals_tb';
           Sources = @((Join-Path $Rtl 'servo_pwm4.sv'),
                       (Join-Path $Rtl 'key_debounce4.sv'),
                       (Join-Path $Rtl 'trash_quiz_controller.sv'),
                       (Join-Path $Rtl 'trash_peripherals.sv'),
                       (Join-Path $Tests 'trash_peripherals_tb.sv')) },
        @{ Name = 'light_panel_tb';
           Sources = @((Join-Path $Rtl 'bcd32.sv'),
                       (Join-Path $Rtl 'ui_light_panel.sv'),
                       (Join-Path $Tests 'light_panel_tb.sv')) }
    )

    foreach ($case in $cases) {
        Write-Output ("=== " + $case.Name)
        foreach ($source in $case.Sources) {
            if (-not (Test-Path -LiteralPath $source)) { throw "Missing source: $source" }
        }
        $log = Join-Path $WorkRoot ($case.Name + '_compile.log')
        & (Join-Path $ModelSim 'vlog.exe') -sv @($case.Sources) 2>&1 | Out-File -FilePath $log -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            Get-Content $log | Select-Object -Last 15
            $failures += ($case.Name + ' (compile)')
            continue
        }
        $runLog = Join-Path $WorkRoot ($case.Name + '_run.log')
        & (Join-Path $ModelSim 'vsim.exe') -c -quiet ('work.' + $case.Name) `
            -do "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" `
            2>&1 | Out-File -FilePath $runLog -Encoding utf8
        $text = Get-Content $runLog -Raw
        if ($text -match 'TEST_PASS') {
            $line = ($text -split "`n" | Where-Object { $_ -match 'TEST_PASS' } | Select-Object -First 1).Trim()
            Write-Output ("  OK  " + $line)
        } else {
            Write-Output "  FAIL no TEST_PASS marker"
            $text -split "`n" | Select-Object -Last 12 | ForEach-Object { Write-Output ("      " + $_) }
            $failures += ($case.Name + ' (run)')
        }
    }
} finally {
    Pop-Location
}

Write-Output ""
Write-Output ("work dir: " + $WorkRoot)
if ($failures.Count -gt 0) {
    Write-Output ("SMOKE_FAIL " + ($failures -join ', '))
    exit 1
}
Write-Output "SMOKE_PASS 3/3"
exit 0
