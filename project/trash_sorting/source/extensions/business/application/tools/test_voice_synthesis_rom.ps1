param([string]$ModelSim = 'D:\FPGA_Project\Modelism\win64')
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = (Get-Item $appRoot).Parent.Parent.Parent.FullName
$sim = Join-Path $appRoot 'build/sim_trash_voice_synthesis_rom'
$evidence = Join-Path $appRoot 'evidence'
New-Item -ItemType Directory -Force -Path $sim,$evidence | Out-Null
# Use the actual synthesis working directory for literal readmemh paths.
Push-Location (Join-Path $projectRoot 'yolo/sources')
try {
    $library = '../../extensions/business/application/build/sim_trash_voice_synthesis_rom/work'
    & (Join-Path $ModelSim 'vlib.exe') $library
    & (Join-Path $ModelSim 'vlog.exe') +define+SYNTHESIS -work $library (Join-Path $appRoot 'rtl/trash_voice_rom_player.v') (Join-Path $appRoot 'tests/trash_voice_rom_full_tb.v')
    if ($LASTEXITCODE -ne 0) { throw 'Synthesis-branch voice RTL compilation failed' }
    $output = & (Join-Path $ModelSim 'vsim.exe') -c -lib $library trash_voice_rom_full_tb -do 'run -all; quit -f' 2>&1
    $output | Set-Content -Encoding UTF8 (Join-Path $evidence 'trash_voice_synthesis_rom_tb.log')
    $output | Write-Output
    if ($LASTEXITCODE -ne 0 -or -not ($output -match 'PASS:') -or ($output -match '\*\* (Fatal|Error)')) {
        throw 'Synthesis-branch ROM sample comparison failed'
    }
} finally { Pop-Location }
