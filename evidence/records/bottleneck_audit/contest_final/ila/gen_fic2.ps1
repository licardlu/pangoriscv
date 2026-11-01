param(
    [string]$ExtractCsv = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\net_names_extract.csv',
    [string]$OutFic     = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\pangoriscv_coremark.fic',
    [string]$ProbeMap   = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\probe_map.txt',
    [string]$Adf        = 'E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila/pangoriscv_top_syn.adf',
    [int]$DataDepth     = 512
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

# Single port layout: trigger bits FIRST (fetch_pc[31:0], fetch_valid at ch 32), then observability data.
$ch = New-Object System.Collections.Generic.List[string]
$ch.AddRange([string[]](Bits 'soc/core/fetch_pc' 32))
$ch.AddRange([string[]](One 'soc/core/fetch_valid'))
$ch.AddRange([string[]](Bits 'soc/core/fetch_inst' 32))
$ch.AddRange([string[]](Bits 'soc/core/cpu/redirect_pc' 32))
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

$L = New-Object System.Collections.Generic.List[string]
$L.Add('#Fabric Core Inserter Project File')
$L.Add('#Hand-generated for CoreMark ILA capture (PG2L100H); single data/trigger port, net names resolved against ADF')
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
$L.Add('Project.unit<0>.triggerMatchCount<0>=2')
$L.Add('Project.unit<0>.triggerMatchCountWidth<0>=0')
$L.Add('Project.unit<0>.triggerMatchType<0>=1')
for ($i=0; $i -lt $ch.Count; $i++) { $L.Add("Project.unit<0>.triggerChannel<0><$i>=$($ch[$i])") }
$L | Set-Content -Path $OutFic -Encoding ascii

Write-Host "channels: $($ch.Count) (trigger bits: ch0..31=pc, ch32=fetch_valid)"
Write-Host "fic: $OutFic ($((Get-Item $OutFic).Length) bytes)"
Write-Host "probe map: $ProbeMap"
