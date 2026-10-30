$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$out = Join-Path $root 'docs\verification'
$inventory = Join-Path $out 'remaining-legacy-delete-files.csv'
$journal = Join-Path $out 'remaining-legacy-cleanup-journal.jsonl'
$resultPath = Join-Path $out 'remaining-legacy-cleanup-result.json'
$python = 'C:\Users\Twinkle Nebula\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if ((Test-Path -LiteralPath $journal) -or (Test-Path -LiteralPath $resultPath)) {
    throw 'A cleanup record already exists. Inspect it; do not overwrite or rerun.'
}
if ((Get-FileHash -LiteralPath $inventory -Algorithm SHA256).Hash -ne '5CEA1F3A7660718C09B7A9CD17539590006E4EBCBD414DAB07CBB0869099D18B') {
    throw 'Reviewed inventory changed; no deletion allowed.'
}
$targets = @(Import-Csv -LiteralPath $inventory)
if ($targets.Count -ne 21) { throw 'Expected exactly 21 reviewed files.' }
if (@($targets.absolute_path | Sort-Object -Unique).Count -ne 21) { throw 'Duplicate target.' }
foreach ($row in $targets) {
    $path = [IO.Path]::GetFullPath($row.absolute_path)
    $expected = [IO.Path]::GetFullPath((Join-Path $root $row.relative_path))
    if ($path -ne $expected -or -not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Out of scope: $path" }
    $rel = $row.relative_path.Replace('\', '/')
    if ($rel -match '^(project/pds_native_120|firmware|docs|evidence|\.git|\.workbuddy|upstream)/' -or
        $rel -match '^build/firmware_' -or $rel -match 'coremark' -or
        $rel -match '^build/core_exact/(native-)?sim-00[12]/(work|reference|replica)(/|$)' -or
        $rel -match '\.(elf|bin|hex|mem|mif|coe|srec|ihex)$') { throw "Protected: $rel" }
    if ($row.category -notin @('retired_reference_entry','retired_entry_bytecode','inactive_reference_netlist')) { throw 'Unreviewed category.' }
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer) { throw "Directory not allowed: $path" }
    $ancestor = $item
    while ($null -ne $ancestor -and $ancestor.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point: $($ancestor.FullName)" }
        if ($ancestor -is [IO.FileInfo]) { $ancestor = $ancestor.Directory } else { $ancestor = $ancestor.Parent }
    }
    if ($item.Length -ne [long]$row.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $row.sha256) { throw "Target changed: $rel" }
}
$package = @(Get-Content -LiteralPath (Join-Path $out 'legacy-reference-cleanup-package-before.json') -Raw | ConvertFrom-Json)
$software = @(Import-Csv -LiteralPath (Join-Path $out 'legacy-reference-keep-coremark.csv'))
function Test-ProtectedFiles {
    $changes = @()
    foreach ($row in $package) {
        if (-not (Test-Path -LiteralPath $row.path -PathType Leaf)) { $changes += $row.path; continue }
        if ((Get-FileHash -LiteralPath $row.path -Algorithm SHA256).Hash -ne $row.sha256) { $changes += $row.path }
    }
    foreach ($row in $software) {
        if (-not (Test-Path -LiteralPath $row.absolute_path -PathType Leaf)) { $changes += $row.absolute_path; continue }
        if ((Get-FileHash -LiteralPath $row.absolute_path -Algorithm SHA256).Hash -ne $row.sha256) { $changes += $row.absolute_path }
    }
    return $changes
}
$before = @(Test-ProtectedFiles)
if ($before.Count -ne 0) { throw ('Protected files differ from recorded baseline: ' + ($before -join ', ')) }
$release = Join-Path $root 'project\pds_native_120'
$beforePaths = @(Get-ChildItem -LiteralPath $release -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]__pycache__[\\/]' } | ForEach-Object { $_.FullName } | Sort-Object)
$deleted = @()
$failure = $null
$verification = $null
try {
    foreach ($row in $targets) {
        Remove-Item -LiteralPath $row.absolute_path -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $row.absolute_path) { throw "Still exists: $($row.relative_path)" }
        $deleted += $row
        [ordered]@{path=$row.relative_path; bytes=[long]$row.bytes; sha256=$row.sha256; deleted_at=(Get-Date).ToString('o')} | ConvertTo-Json -Compress | Add-Content -LiteralPath $journal -Encoding UTF8
    }
    $verifyOutput = & $python -B (Join-Path $release 'tools\build.py') verify 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Standalone verify failed: ' + ($verifyOutput -join "`n")) }
    $verification = ($verifyOutput -join "`n") | ConvertFrom-Json
    if ($verification.status -ne 'PASS') { throw 'Standalone verify did not pass.' }
} catch {
    $failure = $_.Exception.Message
}
$changed = @(Test-ProtectedFiles)
$afterPaths = @(Get-ChildItem -LiteralPath $release -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]__pycache__[\\/]' } | ForEach-Object { $_.FullName } | Sort-Object)
$pathChanges = @(Compare-Object -ReferenceObject $beforePaths -DifferenceObject $afterPaths)
$remaining = @($targets | Where-Object { Test-Path -LiteralPath $_.absolute_path })
$ok = $null -eq $failure -and $changed.Count -eq 0 -and $pathChanges.Count -eq 0 -and $remaining.Count -eq 0 -and $deleted.Count -eq 21
$result = [ordered]@{
    status = $(if ($ok) { 'PASS' } else { 'FAIL' })
    completed_at = (Get-Date).ToString('o')
    reviewed_inventory_sha256 = (Get-FileHash -LiteralPath $inventory -Algorithm SHA256).Hash.ToLowerInvariant()
    deleted_files = $deleted.Count
    freed_logical_bytes = ($deleted | Measure-Object -Property bytes -Sum).Sum
    remaining_targets = @($remaining | ForEach-Object { $_.relative_path })
    failure = $failure
    active_package_files_checked = $package.Count
    active_package_file_set_unchanged = ($pathChanges.Count -eq 0)
    coremark_and_image_files_checked = $software.Count
    changed_protected_files = $changed
    published_bitstream_sha256 = (Get-FileHash -LiteralPath (Join-Path $release 'bitstream\current\pango_replica_core_120.sbit') -Algorithm SHA256).Hash.ToLowerInvariant()
    native_post_deletion_verification = $verification
    upstream_currently_exists = (Test-Path -LiteralPath (Join-Path $root 'upstream'))
    directories_removed = 0
    previously_blocked_targets_attempted = $false
    scope = 'Only the 21 reviewed inactive tools, bytecode caches and old synthesized netlists; active release, CoreMark, licenses, provenance and history retained.'
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
$result | ConvertTo-Json -Depth 10
if (-not $ok) { throw 'Cleanup or verification failed; see separate result record. Do not retry blindly.' }
