`timescale 1ns/1ps
module pll(input clkin1, output reg clkout0=0, output reg clkout1=0,
           output reg clkout2=0, output reg lock=0);
    // Model ratio0=16 with duty0=16: equal high/low halves at 74.25 MHz.
    // The board PLL source and IDF are checked against the same parameters by
    // check.py; this model makes the expected pulse width explicit in RTL sim.
    always begin
        #6.734006734 clkout0 = 1'b1;
        #6.734006734 clkout0 = 1'b0;
    end
    always #50.08417508 clkout1 = ~clkout1;
    always #20.20202020 clkout2 = ~clkout2;
    initial #200 lock = 1;
endmodule

module hdmi_startup_tb;
    reg clk=0;
    always #18.518518518 clk = ~clk;
    wire pixel, vs, hs, de, reset_n, scl, tx;
    wire [7:0] r,g,b;
    tri1 sda;
    hdmi_startup_top #(.REPORT_CYCLES(270000)) dut(
        .sys_clk(clk), .pix_clk(pixel), .vs_out(vs), .hs_out(hs), .de_out(de),
        .r_out(r), .g_out(g), .b_out(b), .rstn_out(reset_n),
        .iic_tx_scl(scl), .iic_tx_sda(sda), .uart_txd(tx));
    integer ticks=0, active=0, hs_ticks=0, vs_ticks=0, rows=0, line_active=0;
    integer colors[0:7];
    integer i;
    reg started=0, previous_vs=0, previous_de=0;
    reg video_done=0, uart_done=0;
    always @(negedge pixel) begin
        if (vs && !previous_vs) begin
            if (started) begin
                if (ticks!=1237500 || active!=921600 || rows!=720 ||
                    hs_ticks!=30000 || vs_ticks!=8250)
                    $fatal(1,"frame totals ticks=%0d active=%0d rows=%0d hs=%0d vs=%0d",
                           ticks,active,rows,hs_ticks,vs_ticks);
                for(i=0;i<8;i=i+1)
                    if(colors[i]!=115200) $fatal(1,"color %0d has %0d pixels",i,colors[i]);
                video_done=1;
            end else begin
                started=1;
                for(i=0;i<8;i=i+1) colors[i]=0;
            end
        end
        if(started && !video_done) begin
            ticks=ticks+1;
            if(hs) hs_ticks=hs_ticks+1;
            if(vs) vs_ticks=vs_ticks+1;
            if(de) begin
                active=active+1; line_active=line_active+1;
                case({r,g,b})
                    24'hffffff: colors[0]=colors[0]+1;
                    24'hffff00: colors[1]=colors[1]+1;
                    24'h00ffff: colors[2]=colors[2]+1;
                    24'h00ff00: colors[3]=colors[3]+1;
                    24'hff00ff: colors[4]=colors[4]+1;
                    24'hff0000: colors[5]=colors[5]+1;
                    24'h0000ff: colors[6]=colors[6]+1;
                    24'h808080: colors[7]=colors[7]+1;
                    default: $fatal(1,"unexpected active color %h",{r,g,b});
                endcase
            end
            if(previous_de && !de) begin
                if(line_active!=1280) $fatal(1,"line width %0d",line_active);
                line_active=0; rows=rows+1;
            end
        end
        previous_vs=vs; previous_de=de;
    end
    localparam real BIT_NS = 234.0*37.037037036;
    reg [7:0] received;
    reg [271:0] uart_message;
    integer byte_index, bit_index;
    initial begin
        uart_message=0;
        for(byte_index=0;byte_index<34;byte_index=byte_index+1) begin
            @(negedge tx); #(BIT_NS/2);
            if(tx!==0) $fatal(1,"short UART start bit");
            for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin
                #(BIT_NS); received[bit_index]=tx;
            end
            #(BIT_NS);
            if(tx!==1) $fatal(1,"missing UART stop bit");
            uart_message={uart_message[263:0],received};
        end
        if(uart_message!={"HDMI720 L=1 R=1 I=0 RD=FF A=0003",8'h0d,8'h0a})
            $fatal(1,"bad UART message: %s",uart_message);
        uart_done=1;
    end
    initial begin
        wait(video_done && uart_done);
        $display("TEST_PASS hdmi_startup frame=1280x720 total=1650x750 bars=8 uart=34");
        $finish;
    end
    initial begin #50000000; $fatal(1,"diagnostic simulation timeout"); end
endmodule
