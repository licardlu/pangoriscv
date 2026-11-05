`timescale 1ns/1ps
// Exercise the real vendor controller with a transaction-level I2C endpoint.
// Check the emitted AVI packet, rather than calling its lookup function.
module hdmi_avi_tb;
    reg clk=0, rstn=0;
    always #5 clk=~clk;
    wire init_over, trigger, write_read;
    wire [7:0] device, write_data;
    wire [15:0] address;
    reg busy=0, byte_over=0;
    reg [7:0] read_data=8'h5a;
    ms7210_ctl dut(.clk(clk), .rstn(rstn), .init_over(init_over),
        .device_id(device), .iic_trig(trigger), .w_r(write_read),
        .addr(address), .data_in(write_data), .busy(busy),
        .data_out(read_data), .byte_over(byte_over));
    integer cycles=0, writes=0, bytes=0, checksum=0;
    reg direction;
    reg [7:0] packet[0:13];
    reg [7:0] header_type=0, header_version=0, header_length=0;
    reg packet_enabled=0;
    always @(posedge clk) begin
        byte_over<=0;
        if (trigger && !busy) begin
            busy<=1; cycles<=0; direction<=write_read;
            if (device!==8'hb2) $fatal(1,"wrong HDMI I2C device");
            if (write_read && address!=16'h0003) begin
                writes=writes+1;
                $display("HDMI_WRITE n=%0d address=%h data=%h",writes,address,write_data);
                case(address)
                    16'h050a: header_type=write_data;
                    16'h0509: header_version=write_data;
                    16'h050b: header_length=write_data;
                    16'h050d: begin
                        if(bytes>=14) $fatal(1,"too many AVI bytes");
                        packet[bytes]=write_data;
                        checksum=checksum+write_data;
                        bytes=bytes+1;
                    end
                    16'h050e: if(write_data==8'h40) begin
                        if(bytes!=14) $fatal(1,"AVI enabled before complete packet");
                        packet_enabled=1;
                    end
                endcase
            end
        end else if (busy) begin
            cycles<=cycles+1;
            // Real I2C pulses byte_over before its stop/write-delay completes.
            if (cycles==4 && direction) byte_over<=1;
            if (cycles==9) busy<=0;
        end
    end
    initial begin
        repeat(4) @(negedge clk); rstn=1;
        wait(init_over); @(negedge clk);
        // The vendor WAIT transition repeats its idempotent 000B=00 write:
        // 49 table entries plus that repeated write, not an extra AVI byte.
        if(writes!=50 || !packet_enabled || bytes!=14)
            $fatal(1,"incomplete HDMI initialization writes=%0d bytes=%0d",writes,bytes);
        if(header_type!=8'h82 || header_version!=2 || header_length!=13)
            $fatal(1,"wrong AVI header");
        if(((checksum+header_type+header_version+header_length)&255)!=0)
            $fatal(1,"invalid AVI checksum");
        if(packet[1][6:5]!=0 || !packet[1][4] || packet[2]!=8'ha8 ||
           packet[3]!=0 || packet[4]!=4)
            $fatal(1,"AVI does not describe RGB BT.709 16:9 VIC4");
        $display("TEST_PASS hdmi_avi writes=50 packet=14 checksum=0 VIC=4");
        $finish;
    end
    initial begin #40000000; $fatal(1,"HDMI initialization timeout"); end
endmodule
