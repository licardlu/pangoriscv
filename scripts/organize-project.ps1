$ErrorActionPreference = 'Stop'
$sourceRoot = 'E:\file\pango'
$targetRoot = $PSScriptRoot

function Copy-Tree([string]$source, [string]$destination) {
    if (!(Test-Path -LiteralPath $source)) { throw "Missing source: $source" }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    & robocopy $source $destination /E /R:1 /W:1 /XJ /XD .git .sim_runs work __pycache__ .pytest_cache /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "Copy failed: $source ($LASTEXITCODE)" }
}

Copy-Tree "$sourceRoot\tinyriscv_axi4" "$targetRoot\01_code\tinyriscv_axi4"
Copy-Tree "$sourceRoot\backups" "$targetRoot\02_original_backups"
Copy-Tree "$sourceRoot\docs" "$targetRoot\03_plans"
foreach ($name in @('led_project', 'project_01_led', '_pin_check')) {
    Copy-Tree "$sourceRoot\$name" "$targetRoot\07_board_references\$name"
}

foreach ($folder in @('04_change_notes','05_verification','06_evidence')) {
    New-Item -ItemType Directory -Path "$targetRoot\$folder" -Force | Out-Null
}
$docs = "$sourceRoot\tinyriscv_axi4\docs"
foreach ($name in @('implementation-status.md','basic-version-handoff.md',
    'cpu_memory_contract.md','native_csr_interrupts.md','provenance.md')) {
    Copy-Item -LiteralPath "$docs\$name" -Destination "$targetRoot\04_change_notes"
}
Copy-Item -LiteralPath "$docs\external-verification-plan.md" -Destination "$targetRoot\05_verification"
Copy-Item -LiteralPath "$sourceRoot\tinyriscv_axi4\tools\NATIVE_SOFTWARE.md" -Destination "$targetRoot\05_verification"
Copy-Tree "$docs\evidence" "$targetRoot\06_evidence\recorded_evidence"

# Preserve readable historical logs without copying simulator binary libraries.
$scanErrors = @()
$logs = Get-ChildItem -LiteralPath "$sourceRoot\tinyriscv_axi4\.sim_runs" -File -Recurse -ErrorAction SilentlyContinue -ErrorVariable +scanErrors |
    Where-Object { $_.Extension -in @('.log','.csv','.txt','.rtr','.json') }
foreach ($file in $logs) {
    $relative = $file.FullName.Substring(("$sourceRoot\tinyriscv_axi4\.sim_runs\").Length)
    $destination = Join-Path "$targetRoot\06_evidence\simulation_logs" $relative
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}
if ($scanErrors.Count) {
    $scanErrors | Out-String | Set-Content -LiteralPath "$targetRoot\06_evidence\unreadable-log-paths.txt" -Encoding utf8
}

# Check every file in the code snapshot against its corresponding source.
$checks = foreach ($file in Get-ChildItem -LiteralPath "$targetRoot\01_code\tinyriscv_axi4" -File -Recurse) {
    $relative = $file.FullName.Substring(("$targetRoot\01_code\tinyriscv_axi4\").Length)
    $source = Join-Path "$sourceRoot\tinyriscv_axi4" $relative
    $targetHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ($targetHash -ne $sourceHash) { throw "Hash mismatch: $relative" }
    [pscustomobject]@{ Path=$relative; Bytes=$file.Length; SHA256=$targetHash; Match=$true }
}
$checks | Export-Csv -LiteralPath "$targetRoot\06_evidence\code-copy-sha256.csv" -NoTypeInformation -Encoding utf8
Write-Output "CODE_FILES_VERIFIED=$($checks.Count)"
Write-Output "LOG_FILES_COPIED=$($logs.Count)"
Write-Output "UNREADABLE_LOG_PATHS=$($scanErrors.Count)"
