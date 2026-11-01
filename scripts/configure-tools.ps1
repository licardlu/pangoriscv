param(
  [string]$GccPrefix = 'D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf',
  [string]$ModelsimBin = 'D:/modeltech64_10.6e/win64',
  [string]$PdsShell = 'D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe',
  [string]$Sbt = 'sbt.bat',
  [string]$Java = 'java'
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
@{gcc_prefix=$GccPrefix; modelsim=$ModelsimBin; pds=$PdsShell; sbt=$Sbt; java=$Java} |
  ConvertTo-Json | Set-Content -Encoding utf8 "$root/tools/local-tools.json"
Write-Output 'Tool paths saved. Firmware/RTL build commands are documented in README.md.'
