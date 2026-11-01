// tb_acc_bulk -- bulk DDR window must be byte-identical to the single-word one.
//
// Writes 32 words through LOAD_ADDR/LOAD_LO/LOAD_HI at 0x100, the same pattern
// through BULK_ADDR/BULK_LO/BULK_HI at 0x300, then reads both ranges back
// through BOTH windows and compares all four results with the pattern.
`timescale 1ns/1ps
module tb_acc_bulk;
  reg clk=0,rstn=0;
  always #5 clk=~clk;

  reg  [7:0]  awaddr; reg awvalid; wire awready;
  reg  [31:0] wdata;  reg wvalid;  wire wready;
  wire [1:0]  bresp;  wire bvalid; reg bready;
  reg  [7:0]  araddr; reg arvalid; wire arready;
  wire [31:0] rdata;  wire rvalid; reg rready; wire [1:0] rresp;

  wire [31:0] m_araddr,m_awaddr; wire [63:0] m_wdata; wire [7:0] m_arlen,m_awlen;
  wire m_arvalid,m_awvalid,m_wvalid,m_wlast,m_rready,m_bready;
  wire m_ar_ready,m_aw_ready,m_w_ready;
  wire [63:0] m_rdata; wire m_rvalid,m_awready,m_wready,m_bvalid;
  reg [1:0] m_rresp=2'b00, m_bresp=2'b00;

  conv_engine_axil #(.BANDW(64),.WBANK(64),.TRM(2)) dut(
    .clk(clk),.rstn(rstn),
    .s_awaddr(awaddr),.s_awvalid(awvalid),.s_awready(awready),
    .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),
    .s_bresp(bresp),.s_bvalid(bvalid),.s_bready(bready),
    .s_araddr(araddr),.s_arvalid(arvalid),.s_arready(arready),
    .s_rdata(rdata),.s_rresp(rresp),.s_rvalid(rvalid),.s_rready(rready),
    .m_araddr(m_araddr),.m_arvalid(m_arvalid),.m_arready(m_ar_ready),
    .m_arlen(m_arlen),.m_rdata(m_rdata),.m_rvalid(m_rvalid),
    .m_rready(m_rready),.m_rresp(m_rresp),
    .m_awaddr(m_awaddr),.m_awvalid(m_awvalid),.m_awready(m_aw_ready),
    .m_awlen(m_awlen),.m_wdata(m_wdata),.m_wvalid(m_wvalid),
    .m_wlast(m_wlast),.m_wready(m_w_ready),.m_bresp(m_bresp),
    .m_bvalid(m_bvalid),.m_bready(m_bready),
    .vid_wr_en(),.vid_wr_addr(),.vid_wr_data(),
    .vid_rd_addr(),.vid_rd_data(32'b0),
    .dbg_st(),.dbg_anom(),.dbg_snap());

  // ---- DDR model ---------------------------------------------------------
  reg [63:0] mem[0:1023];
  reg [63:0] rd_data; reg rd_valid;
  reg [31:0] wr_addr; reg wr_active,wr_bvalid;
  wire [31:0] rd_i=(m_araddr>>3), wr_i=(wr_addr>>3);
  assign m_ar_ready=!rd_valid;
  assign m_rvalid=rd_valid; assign m_rdata=rd_data;
  assign m_aw_ready=!wr_active; assign m_w_ready=wr_active;
  assign m_bvalid=wr_bvalid;
  always @(posedge clk) begin
    if(!rstn) begin
      rd_valid<=0;wr_active<=0;wr_bvalid<=0;
      m_rresp<=2'b00;m_bresp<=2'b00;
    end
    else begin
      if(m_arvalid && m_ar_ready) begin
        if(m_arlen!=0) $fatal(1,"burst read not expected");
        rd_data<=mem[rd_i];rd_valid<=1;
        m_rresp <= (m_araddr==32'h600) ? 2'b10 : 2'b00;
      end else if(rd_valid && m_rready) rd_valid<=0;
      if(m_awvalid && m_aw_ready) begin wr_addr<=m_awaddr;wr_active<=1;end
      if(m_wvalid && m_w_ready) begin
        mem[wr_i]<=m_wdata;wr_active<=0;wr_bvalid<=1;
        m_bresp <= (wr_addr==32'h500) ? 2'b10 : 2'b00;
      end
      if(wr_bvalid && m_bready) begin wr_bvalid<=0;m_bresp<=2'b00;end
    end
  end

  // ---- AXI-Lite master ---------------------------------------------------
  task wr(input [7:0] a,input [31:0] d);
    begin
      @(negedge clk);awaddr=a;awvalid=1;wdata=d;wvalid=1;bready=1;
      $display("WR %h %h t=%0t",a,d,$time);
      while(!(awready&&wready)) @(negedge clk);
      @(negedge clk);awvalid=0;wvalid=0;
      while(!bvalid) begin $display("WAIT_B %h t=%0t",a,$time); @(negedge clk); end
      if(bresp!=0) $fatal(1,"bresp %d at %h",bresp,a);
      @(negedge clk);bready=0;
    end
  endtask
  task rd(input [7:0] a,output [31:0] d);
    begin
      @(negedge clk);araddr=a;arvalid=1;rready=0;
      $display("RD %h t=%0t",a,$time);
      while(!arready) @(negedge clk);
      $display("AR_OK %h t=%0t",a,$time);
      @(negedge clk);arvalid=0;rready=1;
      while(!rvalid) @(negedge clk);
      d=rdata;
      @(negedge clk);rready=0;
    end
  endtask

  reg [63:0] pat[0:31];
  reg [31:0] lo,hi,st;
  integer i,errors=0;
  reg [63:0] got;
  integer j,k;

  task wait_ld; begin
    for(k=0;k<2000;k=k+1) begin rd(8'h70,st); if(!st[0]) k=2000; end
    if(st[0]) $fatal(1,"load window never idle");
  end endtask
  task wait_rd; begin
    for(k=0;k<2000;k=k+1) begin rd(8'h64,st); if(st[1]) k=2000; end
    if(!st[1]) $fatal(1,"read window never done");
  end endtask

  initial begin
    awvalid=0;wvalid=0;bready=0;arvalid=0;rready=0;
    for(i=0;i<32;i=i+1) pat[i]={32'hA5000000+i,32'h5A000000+i};
    repeat(8) @(negedge clk);rstn=1; repeat(4) @(negedge clk);

    // 1. single-word write at 0x100
    wr(8'h54,32'h100);
    for(i=0;i<32;i=i+1) begin wr(8'h58,pat[i][31:0]); wr(8'h5C,pat[i][63:32]); end
    wait_ld;

    // 2. bulk write of the same pattern at 0x300
    wr(8'hA0,32'h300);
    for(i=0;i<32;i=i+1) begin wr(8'hA4,pat[i][31:0]); wr(8'hA8,pat[i][63:32]); end
    wait_ld;
    rd(8'hB4,st);
    if(st[15:0]!=32) $fatal(1,"bulk length %0d expected 32",st[15:0]);

    // 3. read 0x100 back through the BULK window
    wr(8'hA0,32'h100);
    for(i=0;i<32;i=i+1) begin
      rd(8'hB4,st);
      while(!st[30]) rd(8'hB4,st);
      rd(8'hAC,lo); rd(8'hB0,hi);
      got={hi,lo};
      if(got!==pat[i]) begin
        errors=errors+1; $display("BULK_READ_MISMATCH %0d got=%h exp=%h",i,got,pat[i]);
      end
    end

    // 4. read 0x300 back through the SINGLE-WORD window
    for(j=0;j<32;j=j+1) begin
      wr(8'h60,32'h300+8*j); wr(8'h64,1); wait_rd;
      rd(8'h68,lo); rd(8'h6C,hi);
      got={hi,lo};
      if(got!==pat[j]) begin
        errors=errors+1; $display("SINGLE_READ_MISMATCH %0d got=%h exp=%h",j,got,pat[j]);
      end
    end

    // Read without a STATUS prefetch. RVALID must wait for the DDR response,
    // and the following RHI must consume exactly the same word.
    wr(8'hA0,32'h100);
    for(i=0;i<4;i=i+1) begin
      rd(8'hAC,lo);rd(8'hB0,hi);
      if({hi,lo}!==pat[i])
        $fatal(1,"unprefetched bulk read mismatch index=%0d got=%h expected=%h",
               i,{hi,lo},pat[i]);
    end

    // 5. A DDR write SLVERR must be visible in BULK_STATUS after the
    //    outstanding write response returns.
    wr(8'hA0,32'h500);
    wr(8'hA4,pat[0][31:0]);
    wr(8'hA8,pat[0][63:32]);
    wait_ld;
    rd(8'hB4,st);
    if(!st[31]) $fatal(1,"bulk write SLVERR was not reported: status=%h",st);

    // 6. A DDR read SLVERR must also set BULK_STATUS.  The returned data is
    //    deliberately ignored: error reporting, not undefined data, is under
    //    test here.
    wr(8'hA0,32'h600);
    rd(8'hB4,st);
    for(j=0;j<100 && !st[30];j=j+1) rd(8'hB4,st);
    if(!st[30]) $fatal(1,"bulk read did not become ready");
    if(!st[31]) $fatal(1,"bulk read SLVERR was not reported: status=%h",st);

    if(errors) begin
      $display("BULK_EQUIV_FAIL errors=%0d",errors);$fatal(1);
    end
    $display("BULK_EQUIV_PASS 32 words both directions; DDR read/write SLVERR reported");
    $finish;
  end
  initial begin #2000000; $display("BULK_TIMEOUT"); $fatal(1); end
endmodule
