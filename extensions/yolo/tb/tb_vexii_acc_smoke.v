`timescale 1ns/1ps
module tb_vexii_acc_smoke;
  reg clk=0,reset=1;
  always #5 clk=~clk;
  wire [31:0] awaddr,wdata,araddr,rdata;
  wire [3:0] wstrb;
  wire awvalid,wvalid,arvalid,bready,rready;
  wire awready,wready,arready,bvalid,rvalid;
  wire [1:0] bresp,rresp;
  wire [31:0] ma,wa;
  wire mav,mar,mrr,wav,war,wv,wr,wl,br;
  wire [63:0] wd;
  wire [7:0] al,wal;
  reg rv=0,bv=0,ah=0,wh=0;
  reg [63:0] rd=0,hold_data;
  reg [31:0] hold_addr;
  reg [63:0] mem[0:127];
  reg [63:0] dm[0:1023];
  integer i,j,reads=0,writes=0;
  reg uart_rx=1;
  wire uart_tx;
  wire rstn=!cpu.socCtrl_system_reset;
  wire video_write;
  wire [7:0] video_address;
  wire [31:0] video_data;
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
    .ai_rresp(rresp),.ai_rdata(rdata));
  conv_engine_axil #(.BANDW(64),.WBANK(64),.TRM(2)) acc(
    .clk(clk),.rstn(rstn),
    .s_awaddr(awaddr[7:0]),.s_awvalid(awvalid),.s_awready(awready),
    .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),
    .s_bresp(bresp),.s_bvalid(bvalid),.s_bready(bready),
    .s_araddr(araddr[7:0]),.s_arvalid(arvalid),.s_arready(arready),
    .s_rdata(rdata),.s_rresp(rresp),.s_rvalid(rvalid),.s_rready(rready),
    .m_araddr(ma),.m_arvalid(mav),.m_arready(mar),.m_arlen(al),
    .m_rdata(rd),.m_rvalid(rv),.m_rready(mrr),.m_rresp(2'b0),
    .m_awaddr(wa),.m_awvalid(wav),.m_awready(war),.m_awlen(wal),
    .m_wdata(wd),.m_wvalid(wv),.m_wlast(wl),.m_wready(wr),
    .m_bresp(2'b0),.m_bvalid(bv),.m_bready(br),
    .vid_wr_en(video_write),.vid_wr_addr(video_address),
    .vid_wr_data(video_data),.vid_rd_addr(),.vid_rd_data(32'b0),
    .dbg_st(),.dbg_anom(),.dbg_snap());
  assign mar=!rv;
  assign war=!ah&&!bv;
  assign wr=!wh&&!bv;
  always @(posedge clk) if(rstn) begin
    if(mav&&mar) begin
`ifdef FIRMWARE_BOOT
      if(ma<32'h01000000 || al!=0 || ((ma-32'h01000000)>>3)>1023)
        $fatal(1,"bad firmware DDR read %h",ma);
      rd<=dm[(ma-32'h01000000)>>3];
`else
      if(ma[2:0] || ma>=1024 || al!=0) $fatal(1,"bad DDR read");
      rd<=mem[ma>>3];
`endif
      rv<=1;reads<=reads+1;
    end
    if(rv&&mrr) rv<=0;
    if(wav&&war) begin hold_addr<=wa;ah<=1;end
    if(wv&&wr) begin
      if(!wl) $fatal(1,"missing WLAST");
      hold_data<=wd;wh<=1;
    end
    if(ah&&wh&&!bv) begin
`ifdef FIRMWARE_BOOT
      if(hold_addr<32'h01000000 || ((hold_addr-32'h01000000)>>3)>1023)
        $fatal(1,"bad firmware DDR write address %h",hold_addr);
      dm[(hold_addr-32'h01000000)>>3]<=hold_data;
`else
      if(hold_addr!=32'h300 || hold_data!==64'h0c0b0a0908070605)
        $fatal(1,"incorrect convolution output %h %h",hold_addr,hold_data);
      mem[hold_addr>>3]<=hold_data;
`endif
      writes<=writes+1;ah<=0;wh<=0;bv<=1;
    end
    if(bv&&br) bv<=0;
    if(video_write&&video_address==8'hfc) begin
      if(video_data!=32'h600d || writes!=1 || reads<10)
        $fatal(1,"CPU check failed marker=%h reads=%d writes=%d",video_data,reads,writes);
      $display("VEXII_CPU_ACC_PASS real CPU configures convolution and checks DDR result");
      $finish;
    end
  end
`ifdef FIRMWARE_BOOT
  reg [7:0] request_bytes[0:1023],expected_bytes[0:2047];
  reg [7:0] request_frame_lengths[0:26];
  reg [7:0] received_bytes[0:2047],byte_value;
  integer received=0,b,n,sent=0,uart_reads=0,uart_writes=0,peripheral_requests=0,peripheral_responses=0,fetches=0,fetch_responses=0,db_requests=0,db_responses=0;
  integer reply_packets=0;
  integer reply_len=0, reply_pos=0;
  integer request_pos=0,frame,frame_bytes,packet_target,timeout_cycles;
  integer req_cmd,req_len,expected_packet_bytes;
  reg [31:0] req_addr;
  reg [7:0] reply_status=0;
  reg reply_in_packet=0;
  reg [31:0] last_uart_read=0,last_fetch=0,last_db_addr=0;
  always @(posedge clk) if(rstn) begin
    if(cpu.system_cpu_iBus_bus_a_valid && cpu.system_cpu_iBus_bus_a_ready) begin
      fetches<=fetches+1;
      last_fetch<=cpu.system_cpu_iBus_bus_a_payload_address;
    end
    if(cpu.system_cpu_iBus_bus_d_valid && cpu.system_cpu_iBus_bus_d_ready)
      fetch_responses<=fetch_responses+1;
    if(cpu.system_cpu_dBus_bus_a_valid && cpu.system_cpu_dBus_bus_a_ready) begin
      db_requests<=db_requests+1;
      last_db_addr<=cpu.system_cpu_dBus_bus_a_payload_address;
    end
    if(cpu.system_cpu_dBus_bus_d_valid && cpu.system_cpu_dBus_bus_d_ready)
      db_responses<=db_responses+1;
    if(cpu.system_peripheral_bus32_bus_a_valid && cpu.system_peripheral_bus32_bus_a_ready) begin
      peripheral_requests<=peripheral_requests+1;
      if(peripheral_requests<24)
        $display("FW_A t=%0t n=%0d addr=%h op=%d data=%h owner=%b",$time,
          peripheral_requests,cpu.system_peripheral_bus32_bus_a_payload_address,
          cpu.system_peripheral_bus32_bus_a_payload_opcode,
          cpu.system_peripheral_bus32_bus_a_payload_data,cpu.peripheral_ai);
    end
    if(cpu.system_peripheral_bus32_bus_d_valid && cpu.system_peripheral_bus32_bus_d_ready) begin
      peripheral_responses<=peripheral_responses+1;
      if(peripheral_responses<24)
        $display("FW_D t=%0t n=%0d data=%h deny=%b",$time,peripheral_responses,
          cpu.system_peripheral_bus32_bus_d_payload_data,
          cpu.system_peripheral_bus32_bus_d_payload_denied);
    end
  end
  always @(posedge clk) if(rstn &&
      cpu.system_peripheral_uart_logic_core.io_bus_a_valid &&
      cpu.system_peripheral_uart_logic_core.io_bus_a_ready) begin
    if(cpu.system_peripheral_uart_logic_core.io_bus_a_payload_opcode==3'd4) begin
      uart_reads<=uart_reads+1;
      last_uart_read<=cpu.system_peripheral_uart_logic_core.io_bus_d_payload_data;
    end else uart_writes<=uart_writes+1;
  end
`ifdef FAST_UART
  localparam BIT_CYCLES=8;
`else
  localparam BIT_CYCLES=864;
`endif
  initial begin
    wait(rstn);
    forever begin
      @(negedge uart_tx);
      #(BIT_CYCLES*15);
      for(b=0;b<8;b=b+1) begin
        byte_value[b]=uart_tx;
        #(BIT_CYCLES*10);
      end
      if(uart_tx!==1) $fatal(1,"firmware UART stop bit");
      if(received>=2047) $fatal(1,"excess firmware output");
      received_bytes[received]=byte_value;
      received=received+1;
      // Parse the framed reply stream as it arrives.  Do not wait for a
      // hard-coded total: an error reply is shorter than a success reply and
      // must be reported instead of making the testbench wait forever.
      if (!reply_in_packet) begin
        if (received >= 8 &&
            received_bytes[received-8] == "Y" &&
            received_bytes[received-7] == "A" &&
            received_bytes[received-6] == "R" &&
            received_bytes[received-5] == "1") begin
          reply_len = received_bytes[received-3] |
                      (received_bytes[received-2] << 8);
          reply_status = received_bytes[received-4];
          reply_pos = 8;
          reply_in_packet = 1'b1;
          $display("REPLY_HEADER packet=%0d status=%02x len=%0d",
                   reply_packets, reply_status, reply_len);
        end
      end else begin
        reply_pos = reply_pos + 1;
        if (reply_pos == reply_len + 12) begin
          reply_packets = reply_packets + 1;
          reply_in_packet = 1'b0;
          $display("REPLY_PACKET packet=%0d bytes=%0d status=%02x len=%0d",
                   reply_packets-1, reply_len+12, reply_status, reply_len);
        end
      end
    end
  end
  task send_byte(input [7:0] value);
    integer k;
    begin
      @(negedge clk);uart_rx=0;repeat(BIT_CYCLES) @(negedge clk);
      for(k=0;k<8;k=k+1) begin
        uart_rx=value[k];repeat(BIT_CYCLES) @(negedge clk);
      end
      uart_rx=1;repeat(BIT_CYCLES) @(negedge clk);
    sent=sent+1;
    end
  endtask
  initial begin
    $readmemh("request.hex",request_bytes);
    $readmemh("request_frames.hex",request_frame_lengths);
    $readmemh("reply.hex",expected_bytes);
    for(n=0;n<624;n=n+1)
      if(^request_bytes[n]===1'bx) $fatal(1,"missing UART request");
    for(n=0;n<27;n=n+1)
      if(^request_frame_lengths[n]===1'bx)
        $fatal(1,"missing UART request frame length");
    for(n=0;n<516;n=n+1)
      if(^expected_bytes[n]===1'bx) $fatal(1,"missing UART expected response");
    wait(rstn);
    repeat(30000) @(negedge clk);
    // The firmware protocol is stop-and-wait.  Sending all frames as one
    // UART stream overruns its RX FIFO while a command is being processed.
    for(frame=0;frame<27;frame=frame+1) begin
      frame_bytes=request_frame_lengths[frame];
      req_cmd=request_bytes[request_pos+4];
      req_len=request_bytes[request_pos+6] |
              (request_bytes[request_pos+7]<<8);
      req_addr={request_bytes[request_pos+11],request_bytes[request_pos+10],
                request_bytes[request_pos+9],request_bytes[request_pos+8]};
      packet_target=reply_packets+1;
      $display("HOST_REQUEST n=%0d cmd=%0d addr=%08x payload=%0d frame=%0d",
               frame,req_cmd,req_addr,req_len,frame_bytes);
      for(n=0;n<frame_bytes;n=n+1)
        send_byte(request_bytes[request_pos+n]);
      request_pos=request_pos+frame_bytes;
      for(timeout_cycles=0;
          timeout_cycles<200000 && reply_packets<packet_target;
          timeout_cycles=timeout_cycles+1)
        @(negedge clk);
      if(reply_packets<packet_target)
        $fatal(1,"reply timeout request=%0d cmd=%0d addr=%08x",
               frame,req_cmd,req_addr);
      expected_packet_bytes=(req_cmd==2)?20:12;
      $display("HOST_REPLY n=%0d status=%02x payload=%0d bytes=%0d",
               frame,reply_status,reply_len,expected_packet_bytes);
      if(reply_status!==0 || reply_len!==((req_cmd==2)?8:0))
        $fatal(1,"unexpected reply request=%0d cmd=%0d addr=%08x status=%02x len=%0d",
               frame,req_cmd,req_addr,reply_status,reply_len);
    end
    $display("REPLY_BYTES received=%0d packets=%0d expected_packets=27 expected_bytes=516",
             received,reply_packets);
    if(reply_packets<27 || received!=516) begin
      $display("REPLY_SHORT received=%0d packets=%0d",received,reply_packets);
      $fatal(1,"firmware returned fewer complete replies than expected");
    end
    if(request_pos!=624)
      $fatal(1,"not all request bytes were sent: %0d/624",request_pos);
    for(n=0;n<516;n=n+1)
      if(received_bytes[n]!==expected_bytes[n])
        $fatal(1,"UART mismatch at %d got %h expected %h",
               n,received_bytes[n],expected_bytes[n]);
    if(reads!=24 || writes!=24)
      $fatal(1,"incorrect DDR transaction counts reads=%d writes=%d",reads,writes);
    for(n=0;n<24;n=n+1)
      if(dm[n] !== (64'h1122334455667700+n))
        $fatal(1,"DDR word mismatch index=%0d got=%h expected=%h",
               n,dm[n],64'h1122334455667700+n);
    $display("VEXII_FIRMWARE_BOOT_PASS 24-word bulk write + 24 single-word readback");
    $finish;
  end
`endif
  initial begin
    for(i=0;i<128;i=i+1) mem[i]=0;
    for(i=0;i<1024;i=i+1) dm[i]=0;
    mem[0]=64'h0807060504030201;
    // Eight output channels select input channel zero; biases distinguish lanes.
    for(i=0;i<8;i=i+1) mem[32+i]=1;
    for(i=0;i<4;i=i+1) begin
      mem[64+i]={32'(2*i+5),32'(2*i+4)};
      mem[68+i]=64'h0000800000008000;
    end
    mem[96]=64'ha5a5a5a5a5a5a5a5;
    // Generated SoC reset fiber holds system reset for 64 system clocks.
    // Keep the external reset asserted long enough for both synchronizers.
    repeat(160) @(negedge clk);reset=0;
  end
  initial begin #(64'd200000000);
`ifdef FIRMWARE_BOOT
    $display("FW_PROGRESS sent=%0d received=%0d reads=%0d writes=%0d uart_reads=%0d uart_writes=%0d periph_req=%0d periph_rsp=%0d fetch=%0d/%0d last_fetch=%h db=%0d/%0d last_db=%h rx_occupancy=%0d divider=%0d last_rx=%h pending=%b owner=%b reset=%b",
      sent,received,reads,writes,uart_reads,uart_writes,peripheral_requests,peripheral_responses,
      fetches,fetch_responses,last_fetch,db_requests,db_responses,last_db_addr,
      cpu.system_peripheral_uart_logic_core.uartCtrl_1_io_read_queueWithOccupancy_io_occupancy,
      cpu.system_peripheral_uart_logic_core.bridge_uartConfigReg_clockDivider,
      last_uart_read,cpu.peripheral_pending,cpu.peripheral_ai,cpu.socCtrl_system_reset);
`endif
    $fatal(1,"Vexii accelerator timeout");end
endmodule
