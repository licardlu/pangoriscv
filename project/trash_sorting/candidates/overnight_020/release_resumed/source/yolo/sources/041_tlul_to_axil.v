// Single-outstanding 32-bit MMIO bridge. The accelerator accepts only complete
// aligned words, so unsupported TL operations are denied without AXI effects.
`timescale 1ns/1ps
module tlul_to_axil(
  input wire clk,rstn,
  input wire a_valid,
  output wire a_ready,
  input wire [2:0] a_opcode,
  input wire [5:0] a_source,
  input wire [31:0] a_address,a_data,
  input wire [1:0] a_size,
  input wire [3:0] a_mask,
  input wire a_corrupt,
  output wire d_valid,
  input wire d_ready,
  output reg [2:0] d_opcode,
  output reg [5:0] d_source,
  output reg [1:0] d_size,
  output reg d_denied,d_corrupt,
  output reg [31:0] d_data,
  output reg [31:0] awaddr,wdata,araddr,
  output wire [3:0] wstrb,
  output reg awvalid,wvalid,arvalid,
  input wire awready,wready,arready,
  input wire bvalid,
  output wire bready,
  input wire [1:0] bresp,
  input wire rvalid,
  output wire rready,
  input wire [1:0] rresp,
  input wire [31:0] rdata
);
  localparam IDLE=0,WRITE=1,WAIT_B=2,READ=3,WAIT_R=4,REPLY=5;
  reg [2:0] state;
  wire put=(a_opcode==0 || a_opcode==1);
  wire get=(a_opcode==4);
  assign a_ready=rstn && state==IDLE;
  assign d_valid=rstn && state==REPLY;
  assign wstrb=4'b1111;
  assign bready=rstn && state==WAIT_B;
  assign rready=rstn && state==WAIT_R;
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
      state<=IDLE;awvalid<=0;wvalid<=0;arvalid<=0;
      awaddr<=0;wdata<=0;araddr<=0;
      d_opcode<=0;d_source<=0;d_size<=0;
      d_denied<=0;d_corrupt<=0;d_data<=0;
    end else case(state)
      IDLE: if(a_valid) begin
        d_source<=a_source;d_size<=a_size;d_opcode<=put?0:1;
        d_data<=0;d_denied<=0;d_corrupt<=0;
        if((!put&&!get)||a_size!=2||a_address[1:0]!=0||
           a_corrupt||(put&&a_mask!=15)) begin
          d_denied<=1;d_corrupt<=!put;state<=REPLY;
        end else if(put) begin
          awaddr<=a_address;wdata<=a_data;
          awvalid<=1;wvalid<=1;state<=WRITE;
        end else begin araddr<=a_address;arvalid<=1;state<=READ;end
      end
      WRITE: begin
        if(awvalid&&awready) awvalid<=0;
        if(wvalid&&wready) wvalid<=0;
        if((!awvalid||awready)&&(!wvalid||wready)) state<=WAIT_B;
      end
      WAIT_B: if(bvalid) begin
        d_denied<=bresp!=0;state<=REPLY;
      end
      READ: if(arready) begin arvalid<=0;state<=WAIT_R;end
      WAIT_R: if(rvalid) begin
        d_data<=rdata;d_denied<=rresp!=0;
        d_corrupt<=rresp!=0;state<=REPLY;
      end
      REPLY: if(d_ready) state<=IDLE;
      default: state<=IDLE;
    endcase
  end
endmodule
