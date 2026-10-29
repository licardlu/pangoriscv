param([string]$Name='release_7000',[string]$Python='python')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  & $Python scripts/build.py firmware --iterations 7000
  if($LASTEXITCODE -ne 0){throw 'Firmware build failed'}
  & $Python scripts/build.py generate --iterations 7000 --name $Name
  if($LASTEXITCODE -ne 0){throw 'RTL generation failed'}
  & $Python scripts/build.py implement --name $Name
  if($LASTEXITCODE -ne 0){throw 'PDS failed; do not treat a partial build as timing closure'}
} finally {Pop-Location}
