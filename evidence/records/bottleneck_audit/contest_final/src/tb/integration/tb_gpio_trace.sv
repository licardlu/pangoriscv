//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_gpio_trace          File : tb/integration/tb_gpio_trace.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : GPIO trace: drives KEY as the contest plan requires and checks the
//          firmware's post-acquisition report
//=============================================================================

// tb_gpio_trace - drives the KEY input the way the contest plan requires and checks
// the firmware's post-acquisition report.
//
// Requirement reference: the contest plan, trace section
//   "仿真先注入 8 次相隔 100 周期的输入变化，输出 8 条单调时间戳。"
//
// What is checked, and why each check is independent of the firmware:
//   1. 8 records are decoded from the UART stream ("TRACE i=<n> hi=.. lo=.. delta=..").
//   2. The 64-bit timestamps (hi/lo halves) are strictly increasing, and each printed
//      delta equals the difference of the previous two stamps and lies in a window
//      around the injected 100-cycle spacing.  Parsed with $sscanf from the text, so
//      the firmware's own "mono" flag is only corroborating evidence, not the check.
//   3. led[1] (gpio_data[1]) really toggles once per injected edge - counted on the
//      SoC pin wire by this testbench.
//   4. The UART stays silent during acquisition: the first decoded character must
//      arrive after the last injected edge (the plan's "UART 输出放在采集结束后").
//   5. GPIO CTRL was programmed to pin0 = input / pin1 = output.
//
// The failing/IDLE firmware verdict string ("GPIO_TRACE PASS|IDLE|FAIL") stops the run.

module tb_gpio_trace;
    parameter integer BAUD_DIV      = 234;      // 27e6/115200, rtl/perips/axi_uart.v
    parameter integer MAX_CYCLES    = 3000000;  // override with +MAX_CYCLES=<n>
    parameter integer CLK_PERIOD_NS = 1;
    parameter integer INJECT_EDGES  = 8;        // plan: 8 input changes
    parameter integer INJECT_GAP    = 100;      // plan: 100 cycles apart
    parameter integer INJECT_DELAY  = 200;      // cycles after the GPIO CTRL write

    reg clk=0; always #(CLK_PERIOD_NS/2.0) clk=~clk;
    reg rst_n=0;
    reg uart_rx=1, spi_miso=1;
    reg [1:0] gpio_input=0, ext_event=0;        // gpio_input[0] = KEY (active low)
    wire uart_tx,spi_mosi,spi_ss,spi_clk;
    wire [31:0] gpio_ctrl,gpio_data;
    wire halt_req=0, trap_ready=1, irq_software=0, irq_timer=0, irq_external=0;
    reg [4:0] debug_addr=0;
    wire halted;
    wire [31:0] arch_next_pc, trap_cause, trap_pc, trap_tval, csr_mtvec;
    wire trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [63:0] retire_order;
    wire [31:0] retire_pc, retire_inst, wdata, debug_data;
    wire [4:0] rd;

    string prog_file, data_file;
    integer max_cycles;
    integer cycles=0, chars=0, retired=0, traps=0, faults=0;
    integer errors=0, records=0, led_edges=0, first_char_cycle=0, last_inject_cycle=0;
    integer done_count=-1, done_mono=-1, done_toggles=-1, done_capacity=-1, done_entry_bytes=-1;
    integer d_run, d_bytes, d_stop, d_min, d_max, d_window, d_expired, d_polls;
    integer recorded_edges=0;
    reg ctrl_ok=0, done_seen=0, verdict_seen=0;
    string verdict="";
    reg [7:0]  rec_pins[0:63];
    reg [63:0] rec_time[0:63];
    integer    rec_delta[0:63];

    pangoriscv_axi_soc #(.PROGRAM_INIT_FILE(""),.DATA_INIT_FILE(""),
                        .READ_DELAY(0),.WRITE_DELAY(0)) soc(
        .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
        .gpio_input(gpio_input),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
        .spi_miso(spi_miso),.spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
        .ext_event(ext_event),
        .halt_req(halt_req),.halted(halted),.arch_next_pc(arch_next_pc),
        .trap_ready(trap_ready),.trap_vector(32'd0),
        .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire),.trap_cause(trap_cause),.trap_pc(trap_pc),
        .trap_tval(trap_tval),.retire_fire(retire_fire),.retire_order(retire_order),
        .retire_pc(retire_pc),.retire_inst(retire_inst),.rd_valid(rd_valid),
        .rd(rd),.wdata(wdata),.debug_addr(debug_addr),.debug_data(debug_data),
        .protocol_fault(protocol_fault));

    initial begin
        if (!$value$plusargs("PROG=%s", prog_file)) prog_file="program.hex";
        if (!$value$plusargs("DATA=%s", data_file)) data_file="data.hex";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles=MAX_CYCLES;
        $readmemh(prog_file, soc.program_ram.mem);
        $readmemh(data_file, soc.data_ram.mem);
        $display("TRACE_IMAGE prog=%s data=%s max_cycles=%0d", prog_file, data_file, max_cycles);
    end

    always @(posedge clk) if(rst_n) begin
        cycles=cycles+1;
        if(retire_fire) retired=retired+1;
        if(trap_fire)   traps=traps+1;
        if(protocol_fault) faults=faults+1;
    end

    // ---- KEY injection -------------------------------------------------------
    // Fired strictly after the firmware wrote GPIO CTRL, so the first edge can never
    // be missed while the CPU is still in uart_init(): the acquisition window is open
    // by construction.  Four edges leave the pin high, four leave it low (alternating).
    reg ctrl_written=0;
    always @(posedge clk) if(rst_n && soc.gpio_inst.we && soc.gpio_inst.wo==0) ctrl_written=1;
    integer k;
    initial begin
        wait(rst_n==1);
        wait(ctrl_written==1);
        repeat(INJECT_DELAY) @(posedge clk);
        for (k=0;k<INJECT_EDGES;k=k+1) begin
            gpio_input[0] = ~gpio_input[0];
            recorded_edges = recorded_edges + 1;
            last_inject_cycle = cycles;
            $display("TRACE_INJECT edge=%0d cycle=%0d key=%b", k, cycles, gpio_input[0]);
            repeat(INJECT_GAP) @(posedge clk);
        end
    end

    // ---- independent pin-side evidence ---------------------------------------
    // CTRL must be pin0 = 2'b10 (input), pin1 = 2'b01 (output), matching
    // rtl/perips/axi_gpio.v:28,30-31 and the board LED wiring.
    always @(posedge clk) if(rst_n && gpio_ctrl[1:0]==2'b10 && gpio_ctrl[3:2]==2'b01) ctrl_ok=1;

    // One led[1] transition per detected input change.
    reg gpio_led_q=0;
    always @(posedge clk) begin
        gpio_led_q <= gpio_data[1];
        if(rst_n && (gpio_data[1]!==gpio_led_q)) led_edges=led_edges+1;
    end

    // ---- UART TX decoder and line parser --------------------------------------
    reg [15:0] div_cnt=0;
    reg [3:0]  bit_idx=0;
    reg [7:0]  sh=0;
    reg        busy=0;
    reg        tx_q=1;
    string     line="";
    integer    idx, hi, lo, pins, dl;
    integer    j;

    always @(posedge clk) begin
        tx_q <= uart_tx;
        if(!busy) begin
            if(tx_q && !uart_tx) begin
                busy<=1; div_cnt<=(BAUD_DIV/2); bit_idx<=0; sh<=0;
            end
        end else begin
            if(div_cnt==0) begin
                if(bit_idx==0) begin
                    if(uart_tx!==1'b0) $display("TRACE_WARN start bit not low at sample");
                    bit_idx<=1; div_cnt<=BAUD_DIV-1;
                end else if(bit_idx<=8) begin
                    sh[bit_idx-1] = uart_tx;            // blocking: sh is complete now
                    if(bit_idx==8) begin
                        chars=chars+1;
                        if(first_char_cycle==0) first_char_cycle=cycles;
                        $write("%c", sh[7:0]);
                        if(sh[7:0]==8'h0a || sh[7:0]==8'h0d) begin
                            if(line.len()>8 && line.substr(0,7)=="TRACE i=") begin
                                if($sscanf(line,"TRACE i=%d hi=%d lo=%d pins=%d delta=%d",
                                           idx,hi,lo,pins,dl)==5) begin
                                    if(idx>=0 && idx<64) begin
                                        records = records + 1;
                                        rec_time[idx]  = {hi[31:0],lo[31:0]};
                                        rec_pins[idx]  = pins[7:0];
                                        rec_delta[idx] = dl;
                                        if(idx>0) begin
                                            if(rec_time[idx] <= rec_time[idx-1]) begin
                                                errors=errors+1;
                                                $display("TRACE_ERROR timestamp not increasing at i=%0d (%0d <= %0d)",
                                                         idx,rec_time[idx],rec_time[idx-1]);
                                            end
                                            if(dl != (rec_time[idx]-rec_time[idx-1])) begin
                                                errors=errors+1;
                                                $display("TRACE_ERROR delta mismatch at i=%0d printed=%0d actual=%0d",
                                                         idx,dl,rec_time[idx]-rec_time[idx-1]);
                                            end
                                            if(dl < INJECT_GAP/2 || dl > INJECT_GAP*10) begin
                                                errors=errors+1;
                                                $display("TRACE_ERROR delta %0d outside [%0d,%0d] at i=%0d",
                                                         dl,INJECT_GAP/2,INJECT_GAP*10,idx);
                                            end
                                        end
                                        $display("TRACE_REC i=%0d time=%0d pins=%b delta=%0d",idx,rec_time[idx],rec_pins[idx],dl);
                                    end else begin
                                        errors=errors+1;
                                        $display("TRACE_ERROR record index %0d out of range",idx);
                                    end
                                end else begin
                                    errors=errors+1;
                                    $display("TRACE_ERROR cannot parse record line: %s",line);
                                end
                            end else if(line.len()>10 && line.substr(0,9)=="TRACE_DONE") begin
                                if($sscanf(line,"TRACE_DONE run=%d count=%d capacity=%d entry_bytes=%d bytes=%d stop_count=%d mono=%d toggles=%d min_delta=%d max_delta=%d window_ms=%d expired=%d polls=%d",
                                           d_run,done_count,done_capacity,done_entry_bytes,d_bytes,d_stop,done_mono,done_toggles,d_min,d_max,d_window,d_expired,d_polls)==13)
                                    done_seen=1;
                                else begin
                                    errors=errors+1;
                                    $display("TRACE_ERROR cannot parse TRACE_DONE line: %s",line);
                                end
                            end else if(line.len()>12 && line.substr(0,10)=="GPIO_TRACE ") begin
                                verdict = line.substr(11,line.len()-1);
                                verdict_seen = 1;
                            end
                            line="";
                        end else if(sh[7:0]!=8'h0d) begin
                            line = {line, sh[7:0]};
                            if(line.len()>400) line="";
                        end
                    end
                    bit_idx<=bit_idx+1; div_cnt<=BAUD_DIV-1;
                end else begin
                    if(uart_tx!==1'b1) $display("TRACE_WARN stop bit not high");
                    busy<=0; bit_idx<=0;
                end
            end else div_cnt<=div_cnt-1;
        end
    end

    // ---- termination ----------------------------------------------------------
    initial begin
        rst_n=0; uart_rx=1;
        repeat(20) @(negedge clk);
        rst_n=1;
        fork
            begin wait(cycles>=max_cycles); end
            begin
                wait(verdict_seen);
                repeat(4000) @(posedge clk);        // let the line drain
            end
        join_any

        $display("");
        if(!verdict_seen) begin
            errors=errors+1;
            $display("TRACE_ERROR no GPIO_TRACE verdict line within %0d cycles (records=%0d chars=%0d)",
                     max_cycles,records,chars);
        end else if(verdict.len()<4 || verdict.substr(0,3)!="PASS") begin
            errors=errors+1;
            $display("TRACE_ERROR firmware verdict is '%s'",verdict);
        end
        if(records!=INJECT_EDGES) begin
            errors=errors+1;
            $display("TRACE_ERROR decoded %0d records, expected %0d",records,INJECT_EDGES);
        end
        if(!done_seen) begin
            errors=errors+1;
            $display("TRACE_ERROR no TRACE_DONE summary line");
        end else begin
            if(done_count!=INJECT_EDGES) begin
                errors=errors+1;
                $display("TRACE_ERROR summary count=%0d expected %0d",done_count,INJECT_EDGES);
            end
            if(done_mono!=1) begin
                errors=errors+1;
                $display("TRACE_ERROR summary mono=%0d expected 1",done_mono);
            end
        end
        if(led_edges!=INJECT_EDGES) begin
            errors=errors+1;
            $display("TRACE_ERROR led[1] toggled %0d times, expected %0d",led_edges,INJECT_EDGES);
        end
        if(!ctrl_ok) begin
            errors=errors+1;
            $display("TRACE_ERROR GPIO CTRL never became pin0=input/pin1=output (ctrl=%08x)",gpio_ctrl);
        end
        if(first_char_cycle!=0 && last_inject_cycle!=0 && first_char_cycle<=last_inject_cycle) begin
            errors=errors+1;
            $display("TRACE_ERROR UART was active during acquisition (first char cycle=%0d, last edge cycle=%0d)",
                     first_char_cycle,last_inject_cycle);
        end
        $display("TRACE_SUMMARY records=%0d led_edges=%0d ctrl_ok=%b chars=%0d retired=%0d traps=%0d faults=%0d",
                 records,led_edges,ctrl_ok,chars,retired,traps,faults);
        $display("TRACE_SUMMARY summary count=%0d mono=%0d toggles=%0d capacity=%0d entry_bytes=%0d verdict='%s'",
                 done_count,done_mono,done_toggles,done_capacity,done_entry_bytes,verdict);
        $display("TRACE_SUMMARY timing last_inject=%0d first_char=%0d cycles=%0d errors=%0d",
                 last_inject_cycle,first_char_cycle,cycles,errors);
        if(errors==0) $display("TEST_PASS T_GPIO_TRACE records=%0d",records);
        else          $display("TEST_FAIL T_GPIO_TRACE errors=%0d",errors);
        $finish;
    end

    initial begin
        #40000000;
        $display("TRACE_ERROR absolute timeout at %0t (cycles=%0d verdict_seen=%b)",$time,cycles,verdict_seen);
        $display("TEST_FAIL T_GPIO_TRACE absolute timeout");
        $finish;
    end
endmodule
