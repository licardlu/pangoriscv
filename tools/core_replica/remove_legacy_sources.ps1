param([switch]$Execute)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\')
$ExpectedRoot = 'D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv'
if ($Root -ne $ExpectedRoot) { throw 'Unexpected repository root; no deletion allowed' }
$Release = Join-Path $Root 'project/pds_native_120'
$Audit = Join-Path $Root 'docs/verification'
$Python = 'C:\Users\Twinkle Nebula\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$ImageExtensions = @('.elf','.bin','.hex','.mem','.mif','.coe','.srec','.ihex')
$SoftwareNames = @('core_main.c','core_list_join.c','core_matrix.c','core_state.c','core_util.c','coremark.h','core_portme.c','core_portme.h','ee_printf.c','start.s','link.ld','compiler_flags.h')

function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function SaveJson([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 9),[Text.UTF8Encoding]::new($false))
}
function InTree([string]$Path,[string]$Tree) {
    return $Path.Equals($Tree,[StringComparison]::OrdinalIgnoreCase) -or $Path.StartsWith($Tree.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)
}
function SafeTarget($Row,[bool]$Cache) {
    $Rel = [string]$Row.relative_path
    if ([IO.Path]::IsPathRooted($Rel) -or $Rel -match '(^|[\\/])\.\.([\\/]|$)') { throw "Unsafe relative path: $Rel" }
    $Full = [IO.Path]::GetFullPath((Join-Path $Root $Rel))
    if (-not (InTree $Full $Root) -or $Full -eq $Root) { throw "Target outside repository: $Full" }
    if (-not $Full.Equals([IO.Path]::GetFullPath([string]$Row.absolute_path),[StringComparison]::OrdinalIgnoreCase)) { throw 'Absolute/relative manifest paths disagree' }
    $Low = $Rel.Replace('\','/').ToLowerInvariant()
    if ($Low -match '^(project/pds_native_120|firmware|docs|evidence|\.git)(/|$)' -or $Low.Contains('coremark') -or $Low -match '(^|/)firmware_[^/]*(/|$)' -or $ImageExtensions -contains [IO.Path]::GetExtension($Full).ToLowerInvariant() -or $SoftwareNames -contains [IO.Path]::GetFileName($Full).ToLowerInvariant()) {
        throw "Protected target refused: $Full"
    }
    if ($Cache) {
        if ($Low -notmatch '^tools/runtime/' -or $Row.action -ne 'OPTIONAL_CACHE') { throw 'Cache target outside the approved runtime list' }
    } else {
        $Allowed = $Low -match '^(upstream|rtl/core/reference_exact|rtl/soc/reference_exact|rtl/core/replica_native|rtl/soc/replica_native)/'
        $Allowed = $Allowed -or $Low -in @('rtl/generated/microsoc.v','platform/sources/microsoc.v')
        $Allowed = $Allowed -or ($Low.StartsWith('build/') -and [IO.Path]::GetExtension($Full).ToLowerInvariant() -in @('.v','.sv','.vh','.svh','.vhd','.vhdl','.vo','.vm'))
        if (-not $Allowed -or $Row.action -ne 'DELETE_CANDIDATE') { throw "Unapproved source target: $Full" }
    }
    $Ancestor = $Full
    while ((InTree $Ancestor $Root) -and $Ancestor -ne $Root) {
        if (Test-Path -LiteralPath $Ancestor) {
            if ((Get-Item -LiteralPath $Ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point refused: $Ancestor" }
        }
        $Ancestor = Split-Path -Parent $Ancestor
    }
    return $Full
}
function PackageSnapshot {
    $Result = @()
    foreach ($File in (Get-ChildItem -LiteralPath $Release -File -Recurse -Force | Sort-Object FullName)) {
        if ($File.FullName -match '[\\/]__pycache__[\\/]' -or $File.Extension -eq '.pyc') { continue }
        $Result += [pscustomobject]@{ path=$File.FullName; bytes=$File.Length; sha256=(Hash $File.FullName) }
    }
    return ,$Result
}

$SourcesCsv = Join-Path $Audit 'legacy-reference-delete-files.csv'
$CacheCsv = Join-Path $Audit 'legacy-reference-optional-cache.csv'
$KeepCsv = Join-Path $Audit 'legacy-reference-keep-coremark.csv'
$Inventory = Get-Content -LiteralPath (Join-Path $Audit 'legacy-reference-delete-summary.json') -Raw | ConvertFrom-Json
$Sources = @(Import-Csv -LiteralPath $SourcesCsv)
$Cache = @(Import-Csv -LiteralPath $CacheCsv)
$Keep = @(Import-Csv -LiteralPath $KeepCsv)
if ($Sources.Count -ne 972 -or $Cache.Count -ne 39 -or $Keep.Count -ne 327) { throw 'Inventory counts changed; no deletion allowed' }
if ((Hash (Join-Path $Release 'release_manifest.json')) -ne $Inventory.active_release_manifest_sha256) { throw 'Active source release changed since inventory' }
$VerificationText = & $Python (Join-Path $Release 'tools/build.py') verify
if ($LASTEXITCODE -ne 0) { throw 'Independent release verification failed; no deletion allowed' }
$Verification = ($VerificationText -join "`n") | ConvertFrom-Json
if ($Verification.status -ne 'PASS' -or $Verification.external_source_dependencies -ne 0 -or $Verification.memory_lanes -ne 8) { throw 'Independent release source/image closure gate failed' }

# Check the existing GUI project source staging, not only the canonical RTL.
$ProjectBuild = Join-Path $Release 'build/standalone-001'
$Staged = @()
foreach ($Line in Get-Content -LiteralPath (Join-Path $ProjectBuild 'source_list.tcl')) {
    if ($Line -match '^\s*\{(.+)\}\s*$') {
        $Path = [IO.Path]::GetFullPath($Matches[1])
        if (-not (InTree $Path $Release) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'PDS project references a missing/external design source' }
        $Staged += $Path
    }
}
if ($Staged.Count -ne 43 -or -not (Test-Path -LiteralPath (Join-Path $ProjectBuild 'implementation.pds'))) { throw 'Native PDS project staging incomplete' }
$PublishedBit = Join-Path $Release 'bitstream/current/pango_replica_core_120.sbit'
$BitHash = Hash $PublishedBit
if ($BitHash -ne '2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb') { throw 'Published board-proven bitstream changed' }
foreach ($Row in $Keep) {
    if (-not (Test-Path -LiteralPath $Row.absolute_path -PathType Leaf) -or (Hash $Row.absolute_path) -ne $Row.sha256) { throw "Protected CoreMark/image changed: $($Row.relative_path)" }
}
$Targets = @()
$Absent = @()
$Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($Group in @(@{rows=$Sources;cache=$false},@{rows=$Cache;cache=$true})) {
    foreach ($Row in $Group.rows) {
        $Full = SafeTarget $Row $Group.cache
        if (-not $Seen.Add($Full)) { throw 'Duplicate target in approved manifests' }
        if (-not (Test-Path -LiteralPath $Full)) { $Absent += $Full; continue }
        $File = Get-Item -LiteralPath $Full -Force
        if ($File.PSIsContainer -or $File.Length -ne [long]$Row.bytes -or (Hash $Full) -ne $Row.sha256) { throw "Target changed since inventory: $Full" }
        $Targets += [pscustomobject]@{ path=$Full; relative_path=$Row.relative_path; bytes=[long]$Row.bytes; sha256=$Row.sha256; category=$Row.category }
    }
}
$Snapshot = PackageSnapshot
$Preflight = [ordered]@{ status='PASS'; checked_at=[DateTimeOffset]::Now.ToString('o'); mode='preflight_only'; source_files=$Sources.Count; optional_cache_files=$Cache.Count; present_targets=$Targets.Count; already_absent=$Absent.Count; target_bytes=($Targets | Measure-Object bytes -Sum).Sum; protected_coremark_and_images=$Keep.Count; package_files=$Snapshot.Count; package_manifest_sha256=(Hash (Join-Path $Release 'release_manifest.json')); published_bitstream_sha256=$BitHash; staged_pds_sources=$Staged.Count; native_verification=$Verification; sources_csv_sha256=(Hash $SourcesCsv); cache_csv_sha256=(Hash $CacheCsv) }
SaveJson (Join-Path $Audit 'legacy-reference-cleanup-preflight.json') $Preflight
SaveJson (Join-Path $Audit 'legacy-reference-cleanup-package-before.json') $Snapshot
if (-not $Execute) { $Preflight | ConvertTo-Json -Depth 9; return }

# Only individually verified files are removed. No directory, wildcard or
# recursive deletion is used. Protected input trees are never removal targets.
$Journal = Join-Path $Audit 'legacy-reference-cleanup-journal.jsonl'
if (Test-Path -LiteralPath $Journal) { throw 'An execution journal already exists; preserve it for review' }
$Removed = @()
$Failed = @()
foreach ($Target in $Targets) {
    try {
        if ((Hash $Target.path) -ne $Target.sha256) { throw 'File changed after preflight' }
        Remove-Item -LiteralPath $Target.path -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $Target.path) { throw 'File still exists after removal' }
        $Removed += $Target
        $Entry = @{status='deleted'; path=$Target.path; bytes=$Target.bytes; sha256=$Target.sha256}
    } catch {
        $Entry = @{status='failed'; path=$Target.path; error=$_.Exception.Message}
        $Failed += [pscustomobject]$Entry
    }
    [IO.File]::AppendAllText($Journal,(($Entry | ConvertTo-Json -Compress)+"`n"),[Text.UTF8Encoding]::new($false))
}
$PackageErrors = @()
foreach ($File in $Snapshot) {
    if (-not (Test-Path -LiteralPath $File.path -PathType Leaf) -or (Hash $File.path) -ne $File.sha256) { $PackageErrors += $File.path }
}
$KeepErrors = @()
foreach ($Row in $Keep) {
    if (-not (Test-Path -LiteralPath $Row.absolute_path -PathType Leaf) -or (Hash $Row.absolute_path) -ne $Row.sha256) { $KeepErrors += $Row.absolute_path }
}
$AfterText = & $Python (Join-Path $Release 'tools/build.py') verify
$AfterCode = $LASTEXITCODE
$After = $null
if ($AfterCode -eq 0) { $After = ($AfterText -join "`n") | ConvertFrom-Json }
$Remaining = @($Targets | Where-Object { Test-Path -LiteralPath $_.path })
$Success = $Failed.Count -eq 0 -and $PackageErrors.Count -eq 0 -and $KeepErrors.Count -eq 0 -and $Remaining.Count -eq 0 -and $AfterCode -eq 0
$Result = [ordered]@{ status=$(if($Success){'PASS'}else{'PARTIAL_OR_FAILED'}); completed_at=[DateTimeOffset]::Now.ToString('o'); deleted_files=$Removed.Count; deleted_source_files=@($Removed | Where-Object { $_.category -ne 'old_java_scala_runtime' }).Count; deleted_cache_files=@($Removed | Where-Object { $_.category -eq 'old_java_scala_runtime' }).Count; freed_logical_bytes=($Removed | Measure-Object bytes -Sum).Sum; already_absent=$Absent.Count; remaining_target_files=$Remaining.Count; failures=$Failed; active_package_files_checked=$Snapshot.Count; active_package_changed_files=$PackageErrors; coremark_and_image_files_checked=$Keep.Count; coremark_or_image_changed_files=$KeepErrors; published_bitstream_sha256=(Hash $PublishedBit); native_post_deletion_verification=$After; git_history_removed=$false; directories_removed=0; scope='Only files from the two validated inventories; CoreMark, current native PDS, docs, evidence, Git and software images retained' }
SaveJson (Join-Path $Audit 'legacy-reference-cleanup-result.json') $Result
$Result | ConvertTo-Json -Depth 9
if (-not $Success) { throw 'Cleanup incomplete or post-check failed; see the recorded result and journal' }
