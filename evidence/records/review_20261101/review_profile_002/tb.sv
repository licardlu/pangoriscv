`timescale 1ns/1ps
module tb_profile;
  reg clk=0, reset=1;
  always #4.1507024265 clk=~clk;
  wire tx; wire [7:0] leds;
  MicroSoc dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(leds),.system_peripheral_demo_logic_buttons(1'b0));

  // Diagnostic retirement window; firmware mcycle remains authoritative.
  // Hazard reasons overlap; dispatch activity is not retired IPC.
  reg [31:0] profile_start_pc, profile_stop_pc;
  reg active=0, profile_done=0, printed=0;
  initial begin
    if(!$value$plusargs("PROFILE_START=%h",profile_start_pc) ||
       !$value$plusargs("PROFILE_STOP=%h",profile_stop_pc))
      $fatal(1,"ELF-derived profile addresses required");
  end
  longint unsigned sample_cycles=0, lsu_freeze=0, csr_freeze=0, div_freeze=0;
  longint unsigned frontend_stall=0, backend_stall=0, candidates_0=0, candidates_1=0, candidates_2=0, candidates_3=0;
  longint unsigned any_fire=0, multi_fire=0, candidate_fire_0=0, candidate_fire_1=0, candidate_fire_2=0;
  longint unsigned rs_block=0, reservation_block=0, flush_block=0, fence_block=0, pair_block=0, no_lane_block=0;
  longint unsigned icache_miss=0, icache_wait=0, dcache_load_miss=0, lsu_wait=0;
  longint unsigned branch_miss=0, branch_count=0;
  longint unsigned freeze_too_early=0, freeze_wait_rsp=0, freeze_cmd_sent=0;
  longint unsigned freeze_ram_addr=0, freeze_other_addr=0, freeze_cache_miss=0;
  longint unsigned freeze_load=0, freeze_store=0, freeze_hazard=0, freeze_do_it=0;
  integer freeze_samples=0;
  integer i, bit_cycles=1040;
  reg [7:0] ch;
  string line="";
  wire [2:0] cv={dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_ctx_valid,
                 dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_ctx_valid,
                 dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_ctx_valid};
  wire [2:0] cf={dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_fire,
                 dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_fire,
                 dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_fire};
  wire [2:0] do_it={dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_2_doIt,
                    dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_1_doIt,
                    dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_0_doIt};
  wire [2:0] rs_any={|dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_rsHazards,
                     |dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_rsHazards,
                     |dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_rsHazards};
  wire [2:0] reservation_any={|dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_reservationHazards,
                              |dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_reservationHazards,
                              |dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_reservationHazards};
  wire [2:0] flush_any={dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_flushHazards,
                        dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_flushHazards,
                        dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_flushHazards};
  wire [2:0] fence_any={dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_2_fenceOlderHazards,
                        dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_1_fenceOlderHazards,
                        dut.system_cpu_logic_core.DispatchPlugin_logic_candidates_0_fenceOlderHazards};
  wire [2:0] pair_any={dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_2_candHazard,
                       dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_1_candHazard,
                       dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_0_candHazard};
  wire [11:0] layer_available={
    (|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_2_layersHits),
    (|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_1_layersHits),
    (|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_0_layersHits),
    1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0};

  always @(posedge clk) begin
    if(active && !profile_done) begin
      sample_cycles <= sample_cycles+1;
      if(dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_freezeIt) lsu_freeze <= lsu_freeze+1;
      if(dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_freezeIt) begin
        if(dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_tooEarly) freeze_too_early <= freeze_too_early+1;
        if(!dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_tooEarly &&
           !dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_rsp_valid &&
           dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_allowIt) freeze_wait_rsp <= freeze_wait_rsp+1;
        if(dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_cmdSent) freeze_cmd_sent <= freeze_cmd_sent+1;
        if(dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_doIt) freeze_do_it <= freeze_do_it+1;
        if(dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[31:16] == 16'h8000)
          freeze_ram_addr <= freeze_ram_addr+1;
        else freeze_other_addr <= freeze_other_addr+1;
        if(dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_MISS_lane0) freeze_cache_miss <= freeze_cache_miss+1;
        if(dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_LOAD_lane0) freeze_load <= freeze_load+1;
        if(dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_STORE_lane0) freeze_store <= freeze_store+1;
        if(dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_HAZARD_lane0) freeze_hazard <= freeze_hazard+1;
        if(freeze_samples < 12) begin
          $display("FREEZE_SAMPLE addr=%08x load=%b store=%b miss=%b hazard=%b tooEarly=%b allow=%b cmdSent=%b rsp=%b", 
            dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0,
            dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_LOAD_lane0,
            dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_STORE_lane0,
            dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_MISS_lane0,
            dut.system_cpu_logic_core.execute_ctrl4_down_LsuL1_HAZARD_lane0,
            dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_tooEarly,
            dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_allowIt,
            dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_cmdSent,
            dut.system_cpu_logic_core.LsuPlugin_logic_onCtrl_io_rsp_valid);
          freeze_samples <= freeze_samples+1;
        end
      end
      if(dut.system_cpu_logic_core.CsrAccessPlugin_logic_fsm_inject_freeze) csr_freeze <= csr_freeze+1;
      if(dut.system_cpu_logic_core.early0_DivPlugin_logic_processing_freeze) div_freeze <= div_freeze+1;
      if(cv==3'b000) frontend_stall <= frontend_stall+1;
      if((|cv) && (cf==3'b000)) backend_stall <= backend_stall+1;
      case(cv)
        3'b000: candidates_0 <= candidates_0+1;
        3'b001,3'b010,3'b100: candidates_1 <= candidates_1+1;
        3'b011,3'b101,3'b110: candidates_2 <= candidates_2+1;
        default: candidates_3 <= candidates_3+1;
      endcase
      if(|cf) any_fire <= any_fire+1;
      if($countones(cf)>1) multi_fire <= multi_fire+1;
      if(cf[0]) candidate_fire_0 <= candidate_fire_0+1;
      if(cf[1]) candidate_fire_1 <= candidate_fire_1+1;
      if(cf[2]) candidate_fire_2 <= candidate_fire_2+1;
      if((|cv) && (cf==0)) begin
        if(|(rs_any & cv)) rs_block <= rs_block+1;
        if(|(reservation_any & cv)) reservation_block <= reservation_block+1;
        if(|(flush_any & cv)) flush_block <= flush_block+1;
        if(|(fence_any & cv)) fence_block <= fence_block+1;
        if(|(pair_any & cv)) pair_block <= pair_block+1;
        if(((cv[0] && !do_it[0]) && !(|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_0_layersHits)) ||
           ((cv[1] && !do_it[1]) && !(|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_1_layersHits)) ||
           ((cv[2] && !do_it[2]) && !(|dut.system_cpu_logic_core.DispatchPlugin_logic_scheduler_arbiters_2_layersHits)))
          no_lane_block <= no_lane_block+1;
      end
      if(dut.system_cpu_logic_core.FetchL1Plugin_logic_events_miss) icache_miss <= icache_miss+1;
      if(dut.system_cpu_logic_core.FetchL1Plugin_logic_events_waiting) icache_wait <= icache_wait+1;
      if(dut.system_cpu_logic_core.LsuL1Plugin_logic_events_loadMiss) dcache_load_miss <= dcache_load_miss+1;
      if(dut.system_cpu_logic_core.LsuPlugin_logic_events_waiting) lsu_wait <= lsu_wait+1;
      branch_miss <= branch_miss + int'(dut.system_cpu_logic_core.late0_BranchPlugin_logic_events_branchMiss) +
                                   int'(dut.system_cpu_logic_core.late1_BranchPlugin_logic_events_branchMiss);
      branch_count <= branch_count + int'(dut.system_cpu_logic_core.late0_BranchPlugin_logic_events_branchCount) +
                                     int'(dut.system_cpu_logic_core.late1_BranchPlugin_logic_events_branchCount);
    end
  end

  task print_profile;
    begin
      $display("PROFILE_WINDOW cycles=%0d lsu_freeze=%0d csr_freeze=%0d div_freeze=%0d frontend_stall=%0d backend_stall=%0d",sample_cycles,lsu_freeze,csr_freeze,div_freeze,frontend_stall,backend_stall);
      $display("PROFILE_CANDIDATES zero=%0d one=%0d two=%0d three=%0d fire0=%0d fire1=%0d fire2=%0d any_fire=%0d multi_fire=%0d",candidates_0,candidates_1,candidates_2,candidates_3,candidate_fire_0,candidate_fire_1,candidate_fire_2,any_fire,multi_fire);
      $display("PROFILE_BLOCKS rs=%0d reservation=%0d flush=%0d fence=%0d pair=%0d no_lane=%0d",rs_block,reservation_block,flush_block,fence_block,pair_block,no_lane_block);
      $display("PROFILE_MEMORY icache_miss=%0d icache_wait=%0d dcache_load_miss=%0d lsu_wait=%0d",icache_miss,icache_wait,dcache_load_miss,lsu_wait);
      $display("PROFILE_BRANCH miss=%0d count=%0d",branch_miss,branch_count);
      $display("PROFILE_LSU_FREEZE too_early=%0d wait_rsp=%0d cmd_sent=%0d do_it=%0d ram_addr=%0d other_addr=%0d cache_miss=%0d load=%0d store=%0d hazard=%0d",freeze_too_early,freeze_wait_rsp,freeze_cmd_sent,freeze_do_it,freeze_ram_addr,freeze_other_addr,freeze_cache_miss,freeze_load,freeze_store,freeze_hazard);
    end
  endtask

  initial begin
    repeat(20) @(negedge clk); reset=0;
  end
  initial begin
    forever begin
      @(negedge tx);
      repeat(bit_cycles/2) @(posedge clk);
      if(tx!==0) $fatal(1,"UART false start");
      for(i=0;i<8;i=i+1) begin repeat(bit_cycles) @(posedge clk); ch[i]=tx; end
      repeat(bit_cycles) @(posedge clk);
      if(tx!==1) $fatal(1,"UART bad stop");
      if(ch==10) begin
        $display("UART: %s",line);
        if(line.len()>=12 && line.substr(0,10)=="Total ticks") begin
          if(!profile_done) $display("INFO: UART Total ticks seen after PC interval");
        end
        if(line=="BENCH_DONE") begin
          if(!profile_done) $fatal(1,"PROFILE_WINDOW_MISSING");
          $display("TEST_PASS profile_window"); $finish;
        end
        line="";
      end else if(ch!=13) line={line,ch};
    end
  end

  wire commit0 = dut.system_cpu_logic_core.WhiteboxerPlugin_logic_commits_ports_0_valid;
  wire commit1 = dut.system_cpu_logic_core.WhiteboxerPlugin_logic_commits_ports_1_valid;
  wire [31:0] commit_pc0 = dut.system_cpu_logic_core.WhiteboxerPlugin_logic_commits_ports_0_pc;
  wire [31:0] commit_pc1 = dut.system_cpu_logic_core.WhiteboxerPlugin_logic_commits_ports_1_pc;
  always @(posedge clk) begin
    if(!profile_done) begin
      if(!active && ((commit0 && commit_pc0==profile_start_pc) || (commit1 && commit_pc1==profile_start_pc))) begin
        active <= 1'b1;
        $display("PROFILE_START pc=%08x mcycle_read",profile_start_pc);
      end
      if(active && ((commit0 && commit_pc0==profile_stop_pc) || (commit1 && commit_pc1==profile_stop_pc))) begin
        active <= 1'b0;
        profile_done <= 1'b1;

      end
    end
  end
  // Print after NBA updates so the stop cycle is included exactly once.
  always @(negedge clk) if(profile_done && !printed) begin
    printed=1;
    print_profile();
    $display("PROFILE_STOP pc=%08x mcycle_read",profile_stop_pc);
  end
  initial begin
    longint max_cycles;
    max_cycles=40000000;
    if($value$plusargs("MAX_CYCLES=%d",max_cycles)) begin end
    repeat(max_cycles) @(posedge clk);
    $fatal(1,"TIMEOUT profile breakdown");
  end
endmodule
