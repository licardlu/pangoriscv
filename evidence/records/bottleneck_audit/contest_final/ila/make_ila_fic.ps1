# Build the CoreMark ILA configuration file (.fic) offline with cdt_ins.
# Uses the post-synthesis netlist (adf) of the frozen candidate build and the
# connectable-net index map produced by ins_list_nets (nets.csv).
$ErrorActionPreference = 'Stop'
$A = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$ila = Join-Path $A 'contest_final\ila'
$ins = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\cdt_ins.exe'
$adf = Join-Path $ila 'pangoriscv_top_syn.adf'
$ficWin = Join-Path $ila 'pangoriscv_coremark.fic'
$ficTcl = Join-Path $ila 'make_ila_fic.tcl'
$mapCsv = Join-Path $ila 'ila_probe_map.csv'
$triggerPc = 0x1078   # core_list_find (CoreMark list algorithm), performance image

$rows = Import-Csv (Join-Path $ila 'nets.csv')
$idx = @{}
foreach ($r in $rows) {
  $n = $r.name
  if ($n -like '*GTP_*') { continue }          # driver-type column glued to long names
  if (-not $idx.ContainsKey($n)) { $idx[$n] = [int]$r.idx }
}
function Idx([string]$name) {
  if (-not $idx.ContainsKey($name)) { throw "net not found in nets.csv: $name" }
  return $idx[$name]
}
function Bits([string]$fmt, [int]$from, [int]$to) {
  $out = @()
  for ($i = $from; $i -le $to; $i++) { $out += (Idx ($fmt -f $i)) }
  return $out
}

# ---- trigger port: fetch_pc[31:0] then fetch_valid ----
$trigNets = @()
$trigNets += Bits 'soc/core/fetch_pc[{0}]' 0 31
$trigNets += Idx 'soc/core/fetch_valid'

# ---- data port channel list (order defines waveform order) ----
$dataNets = @()
$dataNets += Bits 'soc/core/fetch_pc[{0}]' 0 31
$dataNets += Bits 'soc/core/fetch_inst[{0}]' 0 31
$dataNets += Bits 'soc/core/cpu/redirect_pc[{0}]' 0 31
$dataNets += Bits 'soc/core/ls_req_addr[{0}]' 0 31
$dataNets += Idx 'soc/core/fetch_valid'
$dataNets += Idx 'soc/core/fetch_fault'
$dataNets += Idx 'soc/core/ls_req_write'
$dataNets += Idx 'soc/core/data_cache/hit_any'
$dataNets += Idx 'soc/core/instruction_cache/hit0'
$dataNets += Idx 'soc/perf_i_miss'
$dataNets += Idx 'soc/perf_d_miss'
$dataNets += Idx 'soc/core/cpu/u_if_id/slot/valid_q'
$dataNets += Idx 'soc/core/cpu/u_id_ex/slot/valid_q'
$dataNets += Idx 'soc/fabric/m_arvalid[0]'
$dataNets += Idx 'soc/m_awvalid[1]'
$dataNets += Idx 'soc/m_rvalid[0]'
$dataNets += Idx 'soc/m_rvalid[1]'
$dataNets += Idx 'soc/m_rlast[0]'
$dataNets += Idx 'soc/m_bvalid[1]'
$dataNets += Idx 'soc/m_wready[1]'
$dataNets += Idx 'soc/fabric/target_arready'
# AXI address/write-data buses are mostly pruned in the ADS netlist: only araddr[5..13]
# and araddr[32..63], awaddr[32..63], wdata[32..63], rdata[0..31] survive as nets. Keep only
# rdata[0..31] (real read payload); control/handshake nets above already expose AXI activity.
$dataNets += Bits 'soc/m_rdata[{0}]' 0 31
$clkNets = @((Idx 'nt_clk'))
$rstNets = @((Idx 'nt_rst_n'))

# ---- trigger match values: unit0 assumes channel order LSB-first, unit1 MSB-first ----
$pcBin = [Convert]::ToString($triggerPc, 2).PadLeft(32, '0')
$val = '1' + $pcBin                       # 33 bits: [32]=fetch_valid, [31:0]=pc
$valB = -join ($val[($val.Length-1)..0])   # reversed (other possible channel->bit mapping)

# ---- probe map for evidence ----
$map = @()
for ($i = 0; $i -lt $trigNets.Count; $i++) { $map += [pscustomobject]@{port='trigger0'; channel=$i; net_idx=$trigNets[$i]; net_name=(($rows | Where-Object { [int]$_.idx -eq $trigNets[$i] }).name); width=1} }
for ($i = 0; $i -lt $dataNets.Count; $i++) { $map += [pscustomobject]@{port='data0'; channel=$i; net_idx=$dataNets[$i]; net_name=(($rows | Where-Object { [int]$_.idx -eq $dataNets[$i] }).name); width=1} }
$map += [pscustomobject]@{port='clock'; channel=0; net_idx=$clkNets[0]; net_name='nt_clk'; width=1}
$map += [pscustomobject]@{port='reset'; channel=0; net_idx=$rstNets[0]; net_name='nt_rst_n'; width=1}
$map | Export-Csv $mapCsv -NoTypeInformation -Encoding UTF8

function Fwd([string]$p) { return ($p -replace '\\', '/') }
$lines = @(
  ('ins_new ' + (Fwd $ficWin)),
  ('ins_set_file -input ' + (Fwd $adf)),
  'ins_add_core 1',
  'ins_set_core -core 0 -enable_sq 0 -data_same 0 -data_depth 512 -trig_num 1 -clock_edge 0 -power 0 -multi_windows 0',
  'ins_set_trig -core 0 -trig 0 -unit_num 2 -as_data 0',
  # Connect nets BEFORE ins_set_unit: the match-unit value width must equal the
  # trigger-port width, which is only known once channels exist. The net index list
  # must be one braced Tcl list argument (see Inserter guide ins_set_net parameter).
  ('ins_set_net -core 0 -clock {' + ($clkNets -join ' ') + '}'),
  ('ins_set_net -core 0 -reset {' + ($rstNets -join ' ') + '}'),
  ('ins_set_net -core 0 -trig 0 -connect {' + ($trigNets -join ' ') + '}'),
  ('ins_set_net -core 0 -data -connect {' + ($dataNets -join ' ') + '}'),
  ('ins_set_unit -core 0 -unit 0 -func == -value ' + $val),
  ('ins_set_unit -core 0 -unit 1 -func == -value ' + $valB),
  'ins_set_capture -core 0 -type windows -windows 1 -depth 512 -position 256',
  'ins_set_condition -core 0 -trigger "TU0||TU1"',
  'ins_core_info -core 0 -trig 0 -unit 0',
  'ins_core_info -core 0 -trig 0 -unit 1',
  'ins_save',
  'exit'
)
Set-Content -Path $ficTcl -Value $lines -Encoding ASCII
Write-Host ("trigger nets=" + $trigNets.Count + " data nets=" + $dataNets.Count)
Write-Host ("trigger value A=" + $val)
Write-Host ("trigger value B=" + $valB)
Write-Host ("tcl=" + $ficTcl)

Write-Host ('fic tcl written: ' + $ficTcl)
Write-Host ('probe map written: ' + $mapCsv)

