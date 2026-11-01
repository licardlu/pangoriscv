param(
    [string]$ExtractCsv = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\net_names_extract.csv',
    [string]$OutFic     = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\pangoriscv_coremark.fic',
    [string]$ProbeMap   = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\probe_map.txt',
    [string]$TrigVals   = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\trigger_values.txt',
    [string]$Adf        = 'E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/pangoriscv_top_syn.adf',
    [int]$DataDepth     = 512,
    [UInt32]$TriggerPc  = 0x1078
)

$ErrorActionPreference = 'Stop'
$rows = Get-Content $ExtractCsv | ForEach-Object {
    $p = $_ -split ','
    [pscustomobject]@{ id = [int]$p[0]; name = $p[1]; drv = $p[2] }
}
$byName = @{}
foreach ($r in $rows) { $byName[$r.name] = $r }

function Bits([string]$prefix, [int]$count) {
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $count; $i++) {
        $n = "$prefix[$i]"
        if (-not $byName.ContainsKey($n)) { throw "missing net $n" }
        $out.Add($n)
    }
    return ,$out
}
function One([string]$n) {
    if (-not $byName.ContainsKey($n)) { throw "missing net $n" }
    return @($n)
}

$ch = New-Object System.Collections.Generic.List[string]
$ch.AddRange([string[]](Bits 'soc/core/fetch_pc' 32))
$ch.AddRange([string[]](One 'soc/core/fetch_valid'))
$ch.AddRange([string[]](Bits 'soc/core/fetch_inst' 32))
# redirect_pc[1:0] are always 0 (aligned targets) and get constant-folded by PDS
# dev_map, so the Inserter cannot resolve them in the flattened netlist; skip them.
foreach ($b in 2..31) {
    $n = "soc/core/cpu/redirect_pc[$b]"
    if (-not $byName.ContainsKey($n)) { throw "missing net $n" }
    $ch.Add($n)
}
$ch.AddRange([string[]](Bits 'soc/core/ls_req_addr' 32))
$ch.AddRange([string[]](Bits 'obs_retire_count' 32))
$ch.AddRange([string[]](Bits 'obs_trap_count' 16))
$ch.AddRange([string[]](Bits 'soc/m_rdata' 32))
foreach ($n in @(
    'obs_retire_fire','obs_trap_fire',
    'soc/core/fetch_fault','soc/core/ls_req_write',
    'soc/core/data_cache/hit_any','soc/core/instruction_cache/hit0',
    'soc/perf_i_miss','soc/perf_d_miss',
    'soc/core/cpu/u_if_id/slot/valid_q','soc/core/cpu/u_id_ex/slot/valid_q',
    'soc/fabric/m_arvalid[0]','soc/m_awvalid[1]','soc/m_rvalid[0]','soc/m_rvalid[1]',
    'soc/m_rlast[0]','soc/m_bvalid[1]','soc/m_wready[1]'
)) { $ch.AddRange([string[]](One $n)) }

$ml = New-Object System.Collections.Generic.List[string]
$ml.Add('# channel,net,role')
for ($i=0; $i -lt 32; $i++) { $ml.Add("$i,$($ch[$i]),trigger_pcbit$i") }
$ml.Add("32,$($ch[32]),trigger_fetch_valid")
for ($i=33; $i -lt $ch.Count; $i++) { $ml.Add("$i,$($ch[$i]),data") }
$ml | Set-Content -Path $ProbeMap -Encoding ascii

# ---- trigger value candidates (226-bit binary, X = don't care) ----
$bit = New-Object System.Collections.Generic.List[char]
for ($i=0; $i -lt 32; $i++) { if ((([uint64]$TriggerPc -shr $i) -band 1) -eq 1) { $bit.Add('1') } else { $bit.Add('0') } }
$bit.Add('1')                       # channel 32 = fetch_valid
for ($i=33; $i -lt $ch.Count; $i++) { $bit.Add('X') }
$chars = -join $bit                  # index i = value of channel i
$encA = -join ($bit.ToArray()[($bit.Count-1)..0])   # ch0 = rightmost char (LSB-first reading of literal)
$encB = $chars                                      # ch0 = leftmost char
$tv = @(
    '# trigger PC=0x{0:X} + fetch_valid=1, port width {1}' -f $TriggerPc, $ch.Count
    "encA_ch0_rightmost=$encA"
    "encB_ch0_leftmost=$encB"
) 
$tv | Set-Content -Path $TrigVals -Encoding ascii

# ---- fic (single data/trigger port; matchCount 1 is the value the tool preserves) ----
$L = New-Object System.Collections.Generic.List[string]
$L.Add('#Fabric Core Inserter Project File')
$L.Add('#Hand-generated for CoreMark ILA capture (PG2L100H); single port, net names resolved against ADF')
$L.Add('Project.type=inserter')
$L.Add("Project.device.designInputFile=$Adf")
$L.Add('Project.device.ScanChain=1')
$L.Add('Project.device.UserJtag=0')
$L.Add('Project.Architecture=1 1 1 ')
$L.Add('Project.unit.dimension=1')
$L.Add('Project.unit<0>.clockChannel=nt_clk')
$L.Add('Project.unit<0>.clockEdge=Rising')
$L.Add('Project.unit<0>.ramType=1')
$L.Add("Project.unit<0>.dataDepth=$DataDepth")
$L.Add('Project.unit<0>.dataEqualsTrigger=true')
$L.Add('Project.unit<0>.enablePowerOnInitData=false')
$L.Add('Project.unit<0>.enableStorageQualification=false')
$L.Add('Project.unit<0>.triggerSequencerLevels=1')
$L.Add('Project.unit<0>.enableMultiWindow=false')
$L.Add('Project.unit<0>.triggerPortCount=1')
$L.Add('Project.unit<0>.triggerPortIsData<0>=true')
$L.Add("Project.unit<0>.triggerPortWidth<0>=$($ch.Count)")
$L.Add('Project.unit<0>.triggerMatchCount<0>=1')
$L.Add('Project.unit<0>.triggerMatchCountWidth<0>=0')
$L.Add('Project.unit<0>.triggerMatchType<0>=1')
for ($i=0; $i -lt $ch.Count; $i++) { $L.Add("Project.unit<0>.triggerChannel<0><$i>=$($ch[$i])") }
$L | Set-Content -Path $OutFic -Encoding ascii

Write-Host "channels: $($ch.Count)"
Write-Host "fic: $OutFic ($((Get-Item $OutFic).Length) bytes)"
Write-Host "probe map: $ProbeMap"
Write-Host "trigger values: $TrigVals"
Write-Host "encA length=$($encA.Length) encB length=$($encB.Length)"
