param([string]$ModelSim = 'D:\FPGA_Project\Modelism\win64')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$sim=Join-Path $root 'build/sim_trash_answer_voice_loop'
$log=Join-Path $root 'evidence/trash_answer_voice_loop_sim.log'
New-Item -ItemType Directory -Force -Path $sim,(Split-Path $log -Parent) | Out-Null
Push-Location $sim
try {
    & (Join-Path $ModelSim 'vlib.exe') work
    & (Join-Path $ModelSim 'vlog.exe') -sv -work work ../../rtl/key_debounce4.sv ../../rtl/servo_pwm4.sv ../../rtl/trash_quiz_controller.sv ../../rtl/trash_peripherals.sv ../../rtl/trash_voice_rom_player.v ../../rtl/trash_i2s_tx.v ../../rtl/trash_voice_i2s.v ../../tests/trash_answer_voice_loop_tb.sv
    if($LASTEXITCODE -ne 0) {throw 'Answer/voice-loop compilation failed'}
    $output=& (Join-Path $ModelSim 'vsim.exe') -c -lib work trash_answer_voice_loop_tb -do 'run -all; quit -f' 2>&1
    $output | Set-Content -Encoding UTF8 $log
    $output | Write-Output
    if($LASTEXITCODE -ne 0 -or -not ($output -match 'TEST_PASS trash_answer_voice_loop') -or ($output -match '\*\* (Fatal|Error)')) {
        throw 'Answer/voice-loop simulation failed; see evidence log'
    }
} finally {Pop-Location}
