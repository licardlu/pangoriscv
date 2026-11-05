// tb_vexii_yolo -- full-system bench: Vexii CPU + accelerator MMIO + DDR model.
//
// What is real here:
//   * the generated SoC (vexii_ai_soc.v), the real conv_engine_axil, and the
//     firmware built by build_firmware.py --platform vexii;
//   * every graph operation is driven by the CPU, not by a host script;
//   * the DDR3 device is replaced by a behavioural 64-bit model at the
//     accelerator master port.  The 64->256 bridge and the clock crossing are
//     covered by tb_ddr_bridge / tb_cdc_path and are not repeated here;
//   * the OV5640 is replaced by a file-driven 720p RGB565 stream carrying a
//     fixed test image.
`timescale 1ns/1ps
module tb_vexii_yolo;
  reg clk=0,reset=1;
  always #5 clk=~clk;
  wire rstn=!cpu.socCtrl_system_reset;

  // ---- accelerator AXI4 master (64-bit) ----------------------------------
  wire [31:0] awaddr,wdata,araddr,rdata;
  wire [3:0] wstrb;
  wire awvalid,wvalid,arvalid,bready,rready;
  wire awready,wready,arready,bvalid,rvalid;
  wire [1:0] bresp,rresp;

  wire [31:0] ddr_awaddr,ddr_araddr;
  wire        ddr_awvalid,ddr_awready,ddr_arvalid,ddr_arready;
  wire [7:0]  ddr_awlen,ddr_arlen;
  wire [63:0] ddr_wdata,ddr_rdata;
  wire        ddr_wvalid,ddr_wlast,ddr_wready,ddr_bvalid,ddr_bready;
  wire        ddr_rvalid,ddr_rready;
  wire [1:0]  ddr_bresp,ddr_rresp;

  // ---- video mailbox ------------------------------------------------------
  wire        video_write;
  wire [7:0]  video_address,video_rd_addr;
  wire [31:0] video_data,video_rd;
  reg  cam_vs=0,cam_de=0;
  reg  [15:0] cam_pixel=0;
  reg  pix_vs=0;
  reg  [15:0] pix_in=16'h1082;

  wire uart_tx;
  wire cpu_resetn;
  reg  uart_rx=1;

  vexii_ai_soc cpu(
    .socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_rxd(uart_rx),
    .system_peripheral_uart_logic_uart_txd(uart_tx),
    .system_peripheral_demo_logic_leds(),
    .system_peripheral_demo_logic_buttons(1'b0),
    .ai_awaddr(awaddr),.ai_wdata(wdata),.ai_araddr(araddr),
    .ai_wstrb(wstrb),.ai_awvalid(awvalid),.ai_wvalid(wvalid),
    .ai_arvalid(arvalid),.ai_bready(bready),.ai_rready(rready),
    .ai_awready(awready),.ai_wready(wready),.ai_arready(arready),
    .ai_bvalid(bvalid),.ai_rvalid(rvalid),.ai_bresp(bresp),
    .ai_rresp(rresp),.ai_rdata(rdata),.ai_resetn(cpu_resetn));

  // Match the production engine capacity. The tiny 64/64/2 parameters used by
  // unit tests reject the first 320x320 YOLO layer before issuing DDR traffic.
  conv_engine_axil #(.BANDW(7168),.WBANK(576),.TRM(8)) acc(
    .clk(clk),.rstn(cpu_resetn),
    .s_awaddr(awaddr[7:0]),.s_awvalid(awvalid),.s_awready(awready),
    .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),
    .s_bresp(bresp),.s_bvalid(bvalid),.s_bready(bready),
    .s_araddr(araddr[7:0]),.s_arvalid(arvalid),.s_arready(arready),
    .s_rdata(rdata),.s_rresp(rresp),.s_rvalid(rvalid),.s_rready(rready),
    .m_araddr(ddr_araddr),.m_arvalid(ddr_arvalid),.m_arready(ddr_arready),
    .m_arlen(ddr_arlen),.m_rdata(ddr_rdata),.m_rvalid(ddr_rvalid),
    .m_rready(ddr_rready),.m_rresp(2'b0),
    .m_awaddr(ddr_awaddr),.m_awvalid(ddr_awvalid),.m_awready(ddr_awready),
    .m_awlen(ddr_awlen),.m_wdata(ddr_wdata),.m_wvalid(ddr_wvalid),
    .m_wlast(ddr_wlast),.m_wready(ddr_wready),.m_bresp(2'b0),
    .m_bvalid(ddr_bvalid),.m_bready(ddr_bready),
    .vid_wr_en(video_write),.vid_wr_addr(video_address),
    .vid_wr_data(video_data),.vid_rd_addr(video_rd_addr),
    .vid_rd_data(video_rd),.dbg_st(),.dbg_anom(),.dbg_snap());

  always @(posedge clk) begin
    if(rstn && acc.go)
      $display("ACC_START cin=%0d cout=%0d in=%0dx%0d out=%0dx%0d k=%0d s=%0d pad=%0d tr=%0d t=%0t",
               acc.r_cin,acc.r_cout,acc.r_inw,acc.r_inh,
               acc.r_outw,acc.r_outh,acc.r_k,acc.r_stride,acc.r_pad,acc.r_tr,$time);
    if(rstn && acc.eng_done)
      $display("ACC_DONE err=%0d cycles=%0d t=%0t",acc.eng_err,acc.cycles,$time);
  end

  video_ai_frontend vid(
    .cpu_clk(clk),.cpu_rstn(rstn),
    .wr_en(video_write),.wr_addr(video_address),.wr_data(video_data),
    .rd_addr(video_rd_addr),.rd_data(video_rd),
    .cam_clk(clk),.cam_rstn(rstn),.cam_vs(cam_vs),.cam_de(cam_de),
    .cam_pixel(cam_pixel),
    .pix_clk(clk),.pix_rstn(rstn),.pix_vs(pix_vs),.pix_de(1'b0),
    .pix_in(pix_in),.pix_out());

  // ---- DDR3 behavioural model -------------------------------------------
  localparam [31:0] DDR_BASE=32'h01000000;
  localparam [31:0] INPUT_BASE=32'h02000000;
  localparam integer INPUT_WORDS=102400;
  localparam integer DDR_WORDS=3000000;
  reg [63:0] ddr[0:DDR_WORDS-1];

  integer ddr_writes=0,ddr_reads=0,ddr_bad=0;
  reg [31:0] rd_addr; reg [7:0] rd_len; reg rd_active;
  reg [63:0] rd_data; reg rd_valid;
  reg [31:0] wr_addr; reg [7:0] wr_len; reg wr_active,wr_bvalid;
  wire [31:0] rd_idx=(rd_addr-DDR_BASE)>>3;
  wire [31:0] wr_idx=(wr_addr-DDR_BASE)>>3;

  assign ddr_arready=!rd_active && !rd_valid;
  assign ddr_awready=!wr_active;
  assign ddr_wready=wr_active;
  assign ddr_rvalid=rd_valid;
  assign ddr_bvalid=wr_bvalid;
  assign ddr_rdata=rd_data;
  assign ddr_rresp=2'b0;
  assign ddr_bresp=2'b0;

  always @(posedge clk) begin
    if(!rstn) begin
      rd_active<=0;rd_valid<=0;wr_active<=0;wr_bvalid<=0;rd_len<=0;wr_len<=0;
    end else begin
      if(ddr_arvalid && ddr_arready) begin
        rd_addr<=ddr_araddr;rd_len<=ddr_arlen;rd_active<=1;
        if(ddr_araddr<DDR_BASE || ((ddr_araddr-DDR_BASE)>>3)>=DDR_WORDS) begin
          ddr_bad<=ddr_bad+1;
          $display("DDR_BAD_READ %h t=%0t",ddr_araddr,$time);
        end
      end
      if(rd_active && !rd_valid) begin
        rd_valid<=1;
        rd_data<=(rd_addr>=DDR_BASE && rd_idx<DDR_WORDS)?ddr[rd_idx]:64'h0;
        rd_addr<=rd_addr+8;
        if(rd_len==0) rd_active<=0; else rd_len<=rd_len-1;
        ddr_reads<=ddr_reads+1;
      end else if(rd_valid && ddr_rready) rd_valid<=0;

      if(ddr_awvalid && ddr_awready) begin
        wr_addr<=ddr_awaddr;wr_len<=ddr_awlen;wr_active<=1;
        if(ddr_awaddr<DDR_BASE || ((ddr_awaddr-DDR_BASE)>>3)>=DDR_WORDS) begin
          ddr_bad<=ddr_bad+1;
          $display("DDR_BAD_WRITE %h t=%0t",ddr_awaddr,$time);
        end
      end
      if(ddr_wvalid && ddr_wready) begin
        if(wr_idx<DDR_WORDS && wr_addr>=DDR_BASE) ddr[wr_idx]<=ddr_wdata;
        wr_addr<=wr_addr+8;
        ddr_writes<=ddr_writes+1;
        if(ddr_wlast) begin
          wr_active<=0;wr_bvalid<=1;
        end else if(wr_len!=0) wr_len<=wr_len-1;
      end
      if(wr_bvalid && ddr_bready) wr_bvalid<=0;
    end
  end

  // ---- UART host ---------------------------------------------------------
  localparam integer BIT_CYCLES=864;   // 8 x (107+1) : 115200 at 100 MHz
  reg [7:0] cmd_bytes[0:255];
  integer tx_bytes=0,cmd_n=0,cmd_i=0,uart_fd;
  reg [7:0] rxbuf[0:1023];
  integer rx_cnt=0,rbase=0,rx_len=0,replies=0;
  reg [7:0] rx_sr;

  task send_byte(input [7:0] value);
    integer k;
    begin
      @(negedge clk);uart_rx=0;repeat(BIT_CYCLES) @(negedge clk);
      for(k=0;k<8;k=k+1) begin
        uart_rx=value[k];repeat(BIT_CYCLES) @(negedge clk);
      end
      uart_rx=1;repeat(BIT_CYCLES) @(negedge clk);
    end
  endtask

  task wait_replies(input integer target,input integer max_cycles);
    integer waited;
    begin
      for(waited=0;waited<max_cycles && replies<target;waited=waited+1)
        @(negedge clk);
      if(replies<target)
        $fatal(1,"UART reply timeout target=%0d got=%0d",target,replies);
    end
  endtask

  initial begin : uart_capture
    integer b; reg [7:0] v;
    uart_fd=$fopen("tx.log","w");
    forever begin
      @(negedge uart_tx);
      #(BIT_CYCLES*15);
      for(b=0;b<8;b=b+1) begin
        v[b]=uart_tx;
        #(BIT_CYCLES*10);
      end
      @(posedge clk);
      $fwrite(uart_fd,"%02x\n",v);
      $fflush(uart_fd);
      rxbuf[rx_cnt]=v;
      rx_cnt=rx_cnt+1;
      tx_bytes=tx_bytes+1;
      // frame a YAR1 reply: 8-byte header carries the payload length
      if(rx_cnt-rbase>=8 && rxbuf[rbase]==8'h59 && rxbuf[rbase+1]==8'h41 &&
         rxbuf[rbase+2]==8'h52 && rxbuf[rbase+3]==8'h31) begin
        rx_len=rxbuf[rbase+5]|(rxbuf[rbase+6]<<8);
        if(rx_cnt-rbase>=12+rx_len) begin
          $display("REPLY rx=%0d status=%02x len=%0d",replies,rxbuf[rbase+4],rx_len);
          rbase=rbase+12+rx_len;
          replies=replies+1;
        end
      end
    end
  end

  // ---- camera stream -----------------------------------------------------
  localparam integer SNAP_W=320,SNAP_H=180;
  reg [15:0] frame[0:SNAP_W*SNAP_H-1];
`ifndef PRELOADED_INFERENCE
  initial begin
    integer ci;
    $readmemh("frame.hex",frame);
    for(ci=0;ci<SNAP_W*SNAP_H;ci=ci+1)
      if(^frame[ci]===1'bx) begin
        $display("FRAME_MISSING at %0d",ci);$fatal(1);
      end
  end
`endif
  initial begin : camera
`ifndef PRELOADED_INFERENCE
    integer x,y;
    wait(rstn);
    repeat(2000) @(negedge clk);
    forever begin
      cam_vs=1; repeat(8) @(negedge clk);
      cam_vs=0;
      for(y=0;y<720;y=y+1) begin
        @(negedge clk);cam_de=1;
        for(x=0;x<1280;x=x+1) begin
          cam_pixel<=frame[(y>>2)*SNAP_W+(x>>2)];
          @(negedge clk);
        end
        cam_de=0;
        repeat(4) @(negedge clk);
      end
      repeat(500) @(negedge clk);
    end
`endif
  end
  initial begin : osd_pixels
    wait(rstn);
    forever begin
      pix_vs=1;repeat(4) @(negedge clk);pix_vs=0;
      repeat(300) @(negedge clk);
    end
  end

  // ---- run ---------------------------------------------------------------
  integer n,last_print=0;
  initial begin
    for(n=0;n<256;n=n+1) cmd_bytes[n]=8'hff;
`ifdef PRELOADED_INFERENCE
    $readmemh("cmd_preloaded.hex",cmd_bytes);
    cmd_n=16;
`else
    $readmemh("cmd_full.hex",cmd_bytes);
    cmd_n=32;
`endif
    repeat(160) @(negedge clk);reset=0;
    wait(rstn);
    repeat(40000) @(negedge clk);
`ifdef PRELOADED_INFERENCE
    for(cmd_i=0;cmd_i<cmd_n;cmd_i=cmd_i+1) send_byte(cmd_bytes[cmd_i]);
`else
    // Firmware processes one command at a time; do not overflow its RX FIFO
    // by sending camera inference while the preceding model CRC is running.
    for(cmd_i=0;cmd_i<16;cmd_i=cmd_i+1) send_byte(cmd_bytes[cmd_i]);
    wait_replies(1,800000000);
    for(cmd_i=16;cmd_i<cmd_n;cmd_i=cmd_i+1) send_byte(cmd_bytes[cmd_i]);
`endif
    $display("CMD_SENT bytes=%0d t=%0t",cmd_n,$time);
`ifdef PRELOADED_INFERENCE
    wait_replies(1,800000000);
`else
    wait_replies(2,800000000);
`endif
  end

  always @(posedge clk) if(rstn) begin
    if($time-last_print>5000000) begin
      last_print=$time;
      $display("SIM_PROGRESS t=%0t tx=%0d writes=%0d reads=%0d bad=%0d ld_busy=%b host_busy=%b run=%b ar=%h",
               $time,tx_bytes,ddr_writes,ddr_reads,ddr_bad,
               acc.ld_busy,acc.host_busy,acc.run_active,acc.s_araddr);
      $fflush(uart_fd);
    end
`ifdef PRELOADED_INFERENCE
    if(replies>=1) begin
`else
    if(replies>=2) begin
`endif
      $display("SIM_DONE tx=%0d writes=%0d reads=%0d bad=%0d t=%0t",
               tx_bytes,ddr_writes,ddr_reads,ddr_bad,$time);
      $fclose(uart_fd);$finish;
    end
  end
  initial begin
    #(64'd8000000000);
    $display("SIM_TIMEOUT tx=%0d writes=%0d reads=%0d bad=%0d replies=%0d",
             tx_bytes,ddr_writes,ddr_reads,ddr_bad,replies);
    $fclose(uart_fd);$finish;
  end
  initial begin
    $display("MODEL_PRELOAD_BEGIN");
    $readmemh("ddr_model.hex",ddr,0,232944);
`ifdef PRELOADED_INFERENCE
    $readmemh("ddr_input.hex",ddr,((INPUT_BASE-DDR_BASE)>>3),
              ((INPUT_BASE-DDR_BASE)>>3)+INPUT_WORDS-1);
`endif
    $display("MODEL_PRELOAD_DONE");
  end
endmodule
