"""Generate a local SoC derivative with an uncached accelerator MMIO window."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
CPU=ROOT.parents[1]/"project"/"cpu120"
OUT=ROOT/"gen/integration/vexii_soc"


def generate(cpu=None, out=None):
    global CPU, OUT
    CPU = Path(cpu).resolve() if cpu is not None else CPU
    OUT = Path(out).resolve() if out is not None else OUT
    OUT.mkdir(parents=True,exist_ok=True)
    text=(CPU/"rtl/soc/MicroSoc.v").read_text(encoding="utf-8")
    text=text.replace("module MicroSoc (","module vexii_ai_soc (",1)
    ports=""",
  output wire [31:0] ai_awaddr, ai_wdata, ai_araddr,
  output wire [3:0] ai_wstrb,
  output wire ai_awvalid, ai_wvalid, ai_arvalid, ai_bready, ai_rready,
  input wire ai_awready, ai_wready, ai_arready, ai_bvalid, ai_rvalid,
  input wire [1:0] ai_bresp, ai_rresp,
  input wire [31:0] ai_rdata,
  output wire ai_resetn
"""
    pos=text.index("\n);")
    text=text[:pos]+ports+text[pos:]
    prefix="system_peripheral_bus32_bus_"
    # Serialize the peripheral boundary, retaining ownership through the D ack.
    # This prevents a UART response from being confused with accelerator MMIO.
    addition="""
  wire ai_hit = (system_peripheral_bus32_bus_a_payload_address[28:8]
                 == 21'h100031);
  reg peripheral_pending, peripheral_ai;
  wire ai_tl_ready, ai_tl_valid, ai_tl_denied, ai_tl_corrupt;
  wire [2:0] ai_tl_opcode;
  wire [5:0] ai_tl_source;
  wire [1:0] ai_tl_size;
  wire [31:0] ai_tl_data;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin peripheral_pending<=0; peripheral_ai<=0; end
    else begin
      if(system_peripheral_bus32_bus_a_valid && system_peripheral_bus32_bus_a_ready) begin
        peripheral_pending<=1;
        peripheral_ai<=ai_hit;
      end
      if(system_peripheral_bus32_bus_d_valid && system_peripheral_bus32_bus_d_ready)
        peripheral_pending<=0;
    end
  end
  tlul_to_axil ai_mmio(
    .clk(socCtrl_systemClk), .rstn(!socCtrl_system_reset),
    .a_valid(system_peripheral_bus32_bus_a_valid && ai_hit && !peripheral_pending),
    .a_ready(ai_tl_ready),
    .a_opcode(system_peripheral_bus32_bus_a_payload_opcode),
    .a_source(system_peripheral_bus32_bus_a_payload_source),
    .a_address({3'b0,system_peripheral_bus32_bus_a_payload_address}),
    .a_data(system_peripheral_bus32_bus_a_payload_data),
    .a_size(system_peripheral_bus32_bus_a_payload_size),
    .a_mask(system_peripheral_bus32_bus_a_payload_mask),
    .a_corrupt(system_peripheral_bus32_bus_a_payload_corrupt),
    .d_valid(ai_tl_valid),
    .d_ready(system_peripheral_bus32_bus_d_ready && peripheral_pending && peripheral_ai),
    .d_opcode(ai_tl_opcode), .d_source(ai_tl_source), .d_size(ai_tl_size),
    .d_denied(ai_tl_denied), .d_corrupt(ai_tl_corrupt), .d_data(ai_tl_data),
    .awaddr(ai_awaddr), .wdata(ai_wdata), .araddr(ai_araddr), .wstrb(ai_wstrb),
    .awvalid(ai_awvalid), .wvalid(ai_wvalid), .arvalid(ai_arvalid),
    .awready(ai_awready), .wready(ai_wready), .arready(ai_arready),
    .bvalid(ai_bvalid), .bready(ai_bready), .bresp(ai_bresp),
    .rvalid(ai_rvalid), .rready(ai_rready), .rresp(ai_rresp), .rdata(ai_rdata));
"""
    declarations,implementation=addition.split("  always @",1)
    declarations=declarations.replace(
        "wire ai_hit = (system_peripheral_bus32_bus_a_payload_address[28:8]\n"
        "                 == 21'h100031);", "wire ai_hit;")
    text=text.replace("  localparam A_PUT_FULL_DATA",declarations+
                      "\n  localparam A_PUT_FULL_DATA",1)
    text=text.replace("\nendmodule",
        "\n  assign ai_resetn = !socCtrl_system_reset;\n"
        "  assign ai_hit = system_peripheral_bus32_bus_a_payload_address[28:8] == 21'h100031;\n"
        "  always @"+implementation+"\nendmodule",1)
    start=text.index("  Decoder_2 system_peripheral_bus32_decoder_core (")
    end=text.index("\n  );",start)
    block=text[start:end]
    for port,old,new in (
        ("io_up_a_valid",prefix+"a_valid",prefix+"a_valid && !ai_hit && !peripheral_pending"),
        ("io_up_d_ready",prefix+"d_ready",prefix+"d_ready && peripheral_pending && !peripheral_ai")):
        pattern=r"(\."+port+r"\s*\()\s*"+old+r"\s*(\))"
        block,n=re.subn(pattern,lambda m:m[1]+new+m[2],block)
        if n!=1: raise ValueError("Missing decoder port "+port)
    text=text[:start]+block+text[end:]
    fields={"a_ready":"!peripheral_pending && (ai_hit ? ai_tl_ready : {old})",
            "d_valid":"peripheral_pending && (peripheral_ai ? ai_tl_valid : {old})",
            "d_payload_param":"peripheral_ai ? 3'b0 : {old}"}
    for key,val in (("opcode","opcode"),("source","source"),("size","size"),
                    ("denied","denied"),("data","data"),("corrupt","corrupt")):
        fields["d_payload_"+key]="peripheral_ai ? ai_tl_"+val+" : {old}"
    for field,expr in fields.items():
        pattern=r"(assign "+prefix+field+r"\s*=\s*)([^;]+);"
        text,n=re.subn(pattern,lambda m:m[1]+expr.format(old=m[2])+";",text)
        if n!=1: raise ValueError("Missing response assignment "+field)
    (OUT/"vexii_ai_soc.v").write_text(text,encoding="utf-8")
    # The UART data register read doubles as the receive-FIFO pop, and the
    # generated core drives its low byte from the FIFO RAM output even when the
    # queue is empty.  Empty RAM is X in simulation and uninitialised data on
    # silicon; either value reaches a CPU register and then the PC.  Gate the
    # returned byte with pop_valid so an empty read is a defined zero.  The
    # vendor source tree stays untouched: the patched copy is compiled instead.
    uart=(CPU/"rtl/soc/TilelinkUartCtrl.v").read_text(encoding="utf-8")
    old="busCtrl_rspAsync_payload_data[7 : 0] = bridge_read_streamBroken_payload;"
    new=("busCtrl_rspAsync_payload_data[7 : 0] = "
         "({8{bridge_read_streamBroken_valid}} &"
         " bridge_read_streamBroken_payload);")
    if old not in uart: raise ValueError("UART read-data assignment not found")
    (OUT/"TilelinkUartCtrl.v").write_text(uart.replace(old,new,1),encoding="utf-8")
    print("VEXII_SOC_GENERATED",OUT)


if __name__=="__main__":
    generate()
