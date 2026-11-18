`timescale 1ns/1ps
module ms7210_audio_init_tb;
    reg clk=0;always #5 clk=~clk;
    reg rstn=0,busy=0,byte_over=0;
    reg [7:0] data_out=0;
    wire [15:0] addr;
    wire [7:0] data_in,device_id;
    wire w_r,iic_trig,init_over;
    wire bypass_done,bypass_trigger;
    ms7210_audio_init dut(.*);
    ms7210_audio_init #(.ENABLE(0)) bypass(
        .clk(clk),.rstn(rstn),.busy(1'b0),.data_out(8'b0),.byte_over(1'b0),
        .addr(),.data_in(),.w_r(),.iic_trig(bypass_trigger),
        .init_over(bypass_done),.device_id());
    reg [7:0] registers[0:65535];
    reg [7:0] packet[0:10];
    reg [15:0] active_addr;
    reg [7:0] active_data;
    reg active_write;
    integer delay_left=0,transactions=0,reads=0,writes=0,packet_count=0;
    integer n,sum;
    reg prev_trigger=0;
    always @(posedge clk) begin
        if(!rstn) begin busy<=0;byte_over<=0;prev_trigger<=0;end
        else begin
            byte_over<=0;
            if(bypass_trigger) $fatal(1,"disabled controller generated I2C traffic");
            if(iic_trig && prev_trigger) $fatal(1,"trigger was not a single cycle");
            prev_trigger<=iic_trig;
            if(iic_trig) begin
                if(busy) $fatal(1,"controller triggered a busy bus");
                if(device_id!=8'hb2) $fatal(1,"wrong MS7210 device address");
                busy<=1;delay_left<=5;
                active_addr<=addr;active_data<=data_in;active_write<=w_r;
                transactions=transactions+1;
                if(w_r)writes=writes+1;else reads=reads+1;
            end else if(busy) begin
                if(addr!==active_addr || w_r!==active_write ||
                   (active_write && data_in!==active_data))
                    $fatal(1,"I2C controls changed inside transaction");
                delay_left<=delay_left-1;
                // Make byte_over earlier than bus-idle to catch controllers
                // that launch the write during an unfinished read.
                if(delay_left==2) begin
                    byte_over<=1;
                    if(!active_write)data_out<=registers[active_addr];
                end
                if(delay_left==0) begin
                    busy<=0;
                    if(active_write) begin
                        registers[active_addr]<=active_data;
                        if(active_addr==16'h050d) begin
                            if(packet_count>=11) $fatal(1,"too many Audio InfoFrame bytes");
                            if(registers[16'h050e][5]) $fatal(1,"packet FIFO modified while enabled");
                            packet[packet_count]=active_data;packet_count=packet_count+1;
                        end
                    end
                end
            end
        end
    end
    task expect_reg(input [15:0] a,input [7:0] v);
        if(registers[a]!==v) $fatal(1,"RMW failure %h expected %h actual %h",a,v,registers[a]);
    endtask
    initial begin
        for(n=0;n<65536;n=n+1)registers[n]=8'ha5;
        registers[16'h0006]=8'h80;registers[16'h00a5]=8'he9;
        registers[16'h000b]=8'hff;registers[16'h0048]=8'hb7;
        registers[16'h0008]=8'h23;registers[16'h0503]=8'hab;
        registers[16'h0531]=8'h11;registers[16'h0535]=8'hcf;
        registers[16'h0532]=8'hf8;registers[16'h0570]=8'hfe;
        registers[16'h050e]=8'h47;registers[16'h0507]=8'ha7;
        repeat(5)@(negedge clk);rstn=1;
        wait(init_over);@(negedge clk);
        if(!bypass_done) $fatal(1,"disabled controller failed to finish");
        if(transactions!=46 || reads!=16 || writes!=30)
            $fatal(1,"wrong transaction count %0d/%0d/%0d",transactions,reads,writes);
        expect_reg(16'h0006,8'h91);expect_reg(16'h00a5,8'he1);
        expect_reg(16'h000b,8'hff);expect_reg(16'h0048,8'hb0);
        expect_reg(16'h0008,8'h20);expect_reg(16'h0503,8'haa);
        expect_reg(16'h0530,8'ha4);expect_reg(16'h0531,8'h84);
        expect_reg(16'h0535,8'hdf);expect_reg(16'h0532,8'hf1);
        expect_reg(16'h0570,8'hff);expect_reg(16'h050e,8'h67);
        expect_reg(16'h0507,8'ha3);expect_reg(16'h050a,8'h84);
        expect_reg(16'h0509,8'h01);expect_reg(16'h050b,8'h0a);
        if(packet_count!=11 || packet[0]!=8'h70 || packet[1]!=1)
            $fatal(1,"wrong Audio InfoFrame length/checksum/channel");
        sum=8'h84+8'h01+8'h0a;
        for(n=0;n<11;n=n+1)begin
            sum=sum+packet[n];
            if(n>=2 && packet[n]!=0) $fatal(1,"unexpected Audio InfoFrame payload");
        end
        if((sum&255)!=0)$fatal(1,"invalid Audio InfoFrame checksum");
        repeat(20)@(negedge clk);
        if(transactions!=46 || iic_trig) $fatal(1,"traffic continued after init_over");
        $display("TEST_PASS ms7210_audio_init RMW preserves other bits + 46 transactions + Audio InfoFrame checksum + bypass");
        $finish;
    end
    initial begin #100000;$fatal(1,"timeout");end
endmodule
