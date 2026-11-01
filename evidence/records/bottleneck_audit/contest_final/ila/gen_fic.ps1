param(
    [string]$ExtractCsv = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\net_names_extract.csv',
    [string]$OutFic     = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\pangoriscv_coremark_v1.fic',
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
    $out = @()
    for ($i = 0; $i -lt $count; $i++) {
        $n = "$prefix[$i]"
        if (-not $byName.ContainsKey($n)) { throw "missing net $n" }
        $out += $n
    }
    return $out
}
function One([string]$n) {
    if (-not $byName.ContainsKey($n)) { throw "missing net $n" }
    return @($n)
}

# ---- data port channels ----
$data = New-Object System.Collections.Generic.List[string]
$data.AddRange([string[]](Bits 'soc/core/fetch_pc' 32))
$data.AddRange([string[]](Bits 'soc/core/fetch_inst' 32))
$data.AddRange([string[]](Bits 'soc/core/cpu/redirect_pc' 32))
$data.AddRange([string[]](Bits 'soc/core/ls_req_addr' 32))
$data.AddRange([string[]](Bits 'obs_retire_count' 32))
$data.AddRange([string[]](Bits 'obs_trap_count' 16))
$data.AddRange([string[]](Bits 'soc/m_rdata' 32))
foreach ($n in @(
    'obs_retire_fire','obs_trap_fire',
    'soc/core/fetch_valid','soc/core/fetch_fault','soc/core/ls_req_write',
    'soc/core/data_cache/hit_any','soc/core/instruction_cache/hit0',
    'soc/perf_i_miss','soc/perf_d_miss',
    'soc/core/cpu/u_if_id/slot/valid_q','soc/core/cpu/u_id_ex/slot/valid_q',
    'soc/fabric/m_arvalid[0]','soc/m_awvalid[1]','soc/m_rvalid[0]','soc/m_rvalid[1]',
    'soc/m_rlast[0]','soc/m_bvalid[1]','soc/m_wready[1]'
)) { $data.AddRange([string[]](One $n)) }

# ---- trigger port channels: pc[0..31] + fetch_valid (33 bits) ----
$trig = New-Object System.Collections.Generic.List[string]
$trig.AddRange([string[]](Bits 'soc/core/fetch_pc' 32))
$trig.AddRange([string[]](One 'soc/core/fetch_valid'))

# ---- probe map file ----
$map = 'E:\file\pango\project\evidence\records\bottleneck_audit\contest_final\ila\probe_map_v1.txt'
$ml = New-Object System.Collections.Generic.List[string]
$ml.Add('# port,channel,net')
for ($i=0; $i -lt $data.Count; $i++) { $ml.Add("data,$i,$($data[$i])") }
for ($i=0; $i -lt $trig.Count; $i++) { $ml.Add("trigger,$i,$($trig[$i])") }
$ml | Set-Content -Path $map -Encoding ascii

# ---- fic ----
$L = New-Object System.Collections.Generic.List[string]
$L.Add('#Fabric Core Inserter Project File')
$L.Add('#Hand-generated for CoreMark ILA capture (PG2L100H); net names resolved against synthesized ADF')
$L.Add('Project.type=inserter')
$L.Add("Project.device.designInputFile=$Adf")
$L.Add('Project.device.ScanChain=1')
$L.Add('Project.device.UserJtag=0')
$L.Add('Project.device.deviceFamily=Logos2')
$L.Add('Project.device.deviceModel=PG2L100H')
$L.Add('Project.device.devicePackage=FBG676')
$L.Add('Project.device.deviceSpeedGrade=-6')
$L.Add('Project.Architecture=1 1 1 ')
$L.Add('Project.unit.dimension=1')
$L.Add('Project.unit<0>.clockChannel=nt_clk')
$L.Add('Project.unit<0>.clockEdge=Rising')
$L.Add('Project.unit<0>.ramType=1')
$L.Add("Project.unit<0>.dataDepth=$DataDepth")
$L.Add('Project.unit<0>.dataEqualsTrigger=false')
$L.Add('Project.unit<0>.enablePowerOnInitData=false')
$L.Add('Project.unit<0>.enableStorageQualification=false')
$L.Add('Project.unit<0>.triggerSequencerLevels=1')
$L.Add('Project.unit<0>.enableMultiWindow=false')
$L.Add('Project.unit<0>.triggerPortCount=2')
# data port = port 0
$L.Add('Project.unit<0>.triggerPortIsData<0>=true')
$L.Add("Project.unit<0>.triggerPortWidth<0>=$($data.Count)")
$L.Add('Project.unit<0>.triggerMatchCount<0>=1')
$L.Add('Project.unit<0>.triggerMatchCountWidth<0>=0')
$L.Add('Project.unit<0>.triggerMatchType<0>=1')
for ($i=0; $i -lt $data.Count; $i++) { $L.Add("Project.unit<0>.triggerChannel<0><$i>=$($data[$i])") }
# trigger port = port 1
$L.Add('Project.unit<0>.triggerPortIsData<1>=false')
$L.Add("Project.unit<0>.triggerPortWidth<1>=$($trig.Count)")
$L.Add('Project.unit<0>.triggerMatchCount<1>=2')
$L.Add('Project.unit<0>.triggerMatchCountWidth<1>=0')
$L.Add('Project.unit<0>.triggerMatchType<1>=1')
for ($i=0; $i -lt $trig.Count; $i++) { $L.Add("Project.unit<0>.triggerChannel<1><$i>=$($trig[$i])") }
$L | Set-Content -Path $OutFic -Encoding ascii

Write-Host "data channels: $($data.Count)  trigger channels: $($trig.Count)"
Write-Host "fic: $OutFic  ($((Get-Item $OutFic).Length) bytes)"
Write-Host "probe map: $map"
Write-Host "--- data[0..3] / trigger[32] sample ---"
Write-Host "data0=$($data[0]) data1=$($data[1]) dataLast=$($data[$data.Count-1])"
Write-Host "trigger32=$($trig[32])"
