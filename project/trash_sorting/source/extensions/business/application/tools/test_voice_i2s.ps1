param([string]$ModelSim = 'D:\FPGA_Project\Modelism\win64')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sim = Join-Path $root 'build/sim_trash_voice_i2s'
$evidence = Join-Path $root 'evidence'
New-Item -ItemType Directory -Force -Path $sim,$evidence | Out-Null
Push-Location $sim
try {
    & (Join-Path $ModelSim 'vlib.exe') work
    & (Join-Path $ModelSim 'vlog.exe') -work work ../../rtl/trash_voice_rom_player.v ../../rtl/trash_i2s_tx.v ../../rtl/trash_voice_i2s.v ../../tests/trash_voice_i2s_tb.v ../../tests/trash_voice_rom_full_tb.v
    if ($LASTEXITCODE -ne 0) { throw 'Voice RTL compilation failed' }
    foreach ($tb in @('trash_voice_i2s_tb','trash_voice_rom_full_tb')) {
        $output = & (Join-Path $ModelSim 'vsim.exe') -c -lib work $tb -do 'run -all; quit -f' 2>&1
        $output | Set-Content -Encoding UTF8 (Join-Path $evidence ($tb + '.log'))
        $output | Write-Output
        if ($LASTEXITCODE -ne 0 -or -not ($output -match 'PASS:') -or ($output -match '\*\* (Fatal|Error)')) {
            throw "$tb failed; inspect evidence log"
        }
    }
} finally { Pop-Location }
