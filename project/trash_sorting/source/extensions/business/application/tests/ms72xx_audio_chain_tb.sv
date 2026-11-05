`timescale 1ns/1ps
// Real ms72xx arbitration + real audio init; video init and physical I2C
// transfers are mocked so this checks ownership/ordering, not I2C electronics.
module ms72xx_audio_chain_tb;
    reg clk=0,rst_n=0;always #5 clk=~clk;
    wire init_over_rx,init_over,iic_scl;
    tri1 iic_sda;
    ms72xx_ctl #(.AUDIO_ENABLE(1)) dut(.*);
    integer j;
    initial begin
        repeat(5)@(negedge clk);rst_n=1;
        wait(dut.video_init_over);
        if(init_over) $fatal(1,"overall ready escaped before audio init");
        wait(init_over);@(negedge clk);
        if(dut.iic_dri.mem[16'h050e]!==8'h60)
            $fatal(1,"AVI not preserved / Audio InfoFrame not enabled: %h",dut.iic_dri.mem[16'h050e]);
        if(dut.iic_dri.mem[16'h0531]!==8'h84 || dut.iic_dri.mem[16'h0535][5:4]!==2'b01)
            $fatal(1,"wrong audio rate / word length");
        if(dut.iic_dri.mem[16'h00a5][4:3]!==0 || dut.iic_dri.mem[16'h0008][1:0]!==0)
            $fatal(1,"I2S pads not selected");
        if(dut.iic_dri.transactions!=48)
            $fatal(1,"expected 2 video + 46 audio transfers, got %0d",dut.iic_dri.transactions);
        for(j=0;j<100;j=j+1) begin
            @(negedge clk);
            if(dut.iic_trig!==0 || dut.audio_owner!==0 || dut.video_owner!==0)
                $fatal(1,"post-init bus not quiet or ownership unknown");
        end
        $display("TEST_PASS ms72xx_audio_chain video then audio then quiet idle, gated ready and preserved AVI");
        $finish;
    end
    initial begin #200000;$fatal(1,"HDMI configuration chain timeout");end
endmodule

module ms7210_ctl(input wire clk,rstn,
    output reg init_over,output wire[7:0]device_id,
    output reg iic_trig,w_r,output reg[15:0]addr,output reg[7:0]data_in,
    input wire busy,input wire[7:0]data_out,input wire byte_over);
    reg [2:0]state;
    assign device_id=8'hb2;
    always @(posedge clk) begin
        if(!rstn)begin state<=0;init_over<=0;iic_trig<=0;w_r<=1;addr<=0;data_in<=0;end
        else begin
            iic_trig<=0;
            case(state)
                0:begin addr<=16'h050e;data_in<=8'h40;state<=1;end
                1:begin iic_trig<=1;state<=2;end
                2:if(busy)state<=3;
                3:if(!busy)begin addr<=16'h0507;data_in<=8'hff;state<=4;end
                4:begin iic_trig<=1;state<=5;end
                5:if(busy)state<=6;
                6:if(!busy)begin init_over<=1;state<=7;end
                7:begin end
            endcase
        end
    end
endmodule

// Deliberately X on the unused receiver mimics an unclocked legacy block.
module ms7200_ctl(input wire clk,rstn,output wire init_over,
    output wire[7:0]device_id,output wire iic_trig,w_r,
    output wire[15:0]addr,output wire[7:0]data_in,
    input wire busy,input wire[7:0]data_out,input wire byte_over);
    assign init_over=1'bx;assign device_id=8'hxx;
    assign iic_trig=1'bx;assign w_r=1'bx;assign addr=16'hxxxx;assign data_in=8'hxx;
endmodule

module iic_dri #(
    parameter CLK_FRE=10000000,IIC_FREQ=400000,T_WR=1,ADDR_BYTE=2,LEN_WIDTH=3,DATA_BYTE=1
)(input wire clk,rstn,input wire[7:0]device_id,input wire pluse,w_r,
    input wire[LEN_WIDTH:0]byte_len,input wire[15:0]addr,input wire[7:0]data_in,
    output reg busy,byte_over,output reg[7:0]data_out,
    output wire scl,input wire sda_in,output wire sda_out,sda_out_en);
    reg [7:0]mem[0:65535];
    reg [3:0]remaining;
    reg [15:0]saved_addr;
    reg [7:0]saved_data;
    reg saved_write;
    integer i,transactions=0;
    initial for(i=0;i<65536;i=i+1)mem[i]=8'hff;
    assign scl=1;assign sda_out=1;assign sda_out_en=0;
    always @(posedge clk) begin
        if(!rstn)begin busy<=0;byte_over<=0;data_out<=0;remaining<=0;transactions<=0;end
        else begin
            byte_over<=0;
            if(pluse) begin
                if(busy) $fatal(1,"overlapping I2C owner requests");
                if(device_id!==8'hb2) $fatal(1,"wrong I2C owner/address");
                busy<=1;remaining<=6;saved_addr<=addr;saved_data<=data_in;saved_write<=w_r;
                transactions<=transactions+1;
            end else if(busy) begin
                remaining<=remaining-1'b1;
                if(remaining==3)byte_over<=1;
                if(remaining==1)begin
                    if(saved_write)mem[saved_addr]<=saved_data;
                    else data_out<=mem[saved_addr];
                    busy<=0;
                end
            end
        end
    end
endmodule
