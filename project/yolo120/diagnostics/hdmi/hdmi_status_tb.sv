`timescale 1ns/1ps
// Exercise the scanner with variable transfer lengths, including busy stalls.
// These interface models are used only in the separate status-test library.
module pll(input clkin1, output clkout0, clkout1, clkout2, output reg lock=0);
    assign clkout0=clkin1; assign clkout1=clkin1; assign clkout2=clkin1;
    initial #25 lock=1;
endmodule
module sync_vg(input clk,rstn,output vs_out,hs_out,de_out,de_re,
               output [11:0] x_act,y_act);
    assign {vs_out,hs_out,de_out,de_re,x_act,y_act}=0;
endmodule
module ms7210_ctl(input clk,rstn, output reg init_over=0,
    output [7:0] device_id, output reg iic_trig=0, output reg w_r=1,
    output reg [15:0] addr=16'h0003, output [7:0] data_in,
    input busy, input [7:0] data_out, input byte_over);
    assign device_id=8'hb2; assign data_in=8'h5a;
    reg old_busy=0, started=0;
    integer completed=0;
    always @(posedge clk) begin
        old_busy<=busy;
        iic_trig<=0;
        if (!rstn) begin
            started<=0; completed<=0; init_over<=0; w_r<=1;
        end else if (!started) begin
            started<=1; iic_trig<=1;
        end else if (old_busy && !busy) begin
            completed<=completed+1; iic_trig<=1;
            // Two writes, then one read before handing over to the scanner.
            if (completed==1) w_r<=0;
            if (completed==2) begin init_over<=1; addr<=16'h0502; end
        end
    end
endmodule
module iic_dri #(parameter CLK_FRE=1,IIC_FREQ=1,T_WR=1,ADDR_BYTE=2,
    LEN_WIDTH=3,DATA_BYTE=1)(input clk,rstn,input [7:0] device_id,
    input pluse,w_r,input [LEN_WIDTH:0] byte_len,input [15:0] addr,
    input [7:0] data_in,output reg busy=0,output reg byte_over=0,
    output reg [7:0] data_out=0,output scl,input sda_in,
    output sda_out,sda_out_en);
    assign scl=1; assign sda_out=1; assign sda_out_en=0;
    integer count=0, transfers=0;
    reg [15:0] held_address;
    reg held_direction;
    always @(posedge clk) begin
        byte_over<=0;
        if (pluse && !busy) begin
            busy<=1; count<=0; transfers<=transfers+1;
            held_address<=addr; held_direction<=w_r;
            if (transfers>=2 && w_r) $fatal(1,"unexpected status write");
        end else if (busy) begin
            if (addr!==held_address || w_r!==held_direction)
                $fatal(1,"I2C request changed while busy");
            count<=count+1;
            if (count==3+(transfers%7)) begin
                busy<=0; byte_over<=1;
                // Address-derived response makes stale address/data pairing fail.
                data_out<=held_address[15:8]^held_address[7:0];
            end
        end
    end
endmodule
module hdmi_status_tb;
    reg clk=0; always #5 clk=~clk;
    wire [7:0] r,g,b; wire pixel,vs,hs,de,reset_n,scl,tx; tri1 sda;
    hdmi_startup_top #(.SYS_HZ(1000000),.REPORT_CYCLES(20000),.SCAN_CYCLES(80)) dut(
        .sys_clk(clk),.pix_clk(pixel),.vs_out(vs),.hs_out(hs),.de_out(de),
        .r_out(r),.g_out(g),.b_out(b),.rstn_out(reset_n),
        .iic_tx_scl(scl),.iic_tx_sda(sda),.uart_txd(tx));
    reg [15:0] seen=0;
    reg [15:0] expected [0:15];
    initial begin
        expected[0]='h0502; expected[1]='h051d; expected[2]='h0507; expected[3]='h0900;
        expected[4]='h0906; expected[5]='h090f; expected[6]='h091f; expected[7]='h0920;
        expected[8]='h1200; expected[9]='h1202; expected[10]='h1206; expected[11]='h120b;
        expected[12]='h00c0; expected[13]='h0016; expected[14]='h0009; expected[15]='h1281;
        wait (dut.scanning);
        while (seen!=16'hffff) begin
            @(negedge clk);
            if (dut.busy_d && !dut.busy && dut.scan_count<80) begin
                @(negedge clk);
                if (dut.last_address!==expected[dut.scan_index] ||
                    dut.last_read!==(dut.last_address[15:8]^dut.last_address[7:0]))
                    $fatal(1,"incoherent status addr=%h data=%h index=%d",
                        dut.last_address,dut.last_read,dut.scan_index);
                seen[dut.scan_index]=1;
            end
        end
        $display("TEST_PASS hdmi_status read_only=16 coherent=1 busy_stalls=1");
        $finish;
    end
    initial begin #500000; $fatal(1,"scanner timeout"); end
endmodule
