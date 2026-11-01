`timescale 1ns/1ps
module tb_video_frontend;
    reg cpu_clk=0,pix_clk=0,cam_clk=0,cpu_rstn=0,pix_rstn=0,cam_rstn=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 pix_clk=~pix_clk;
    always #9 cam_clk=~cam_clk;
    reg wr_en=0;
    reg [7:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    wire [31:0] rd_data;
    reg cam_vs=0,cam_de=0,pix_vs=0,pix_de=0;
    reg [15:0] cam_pixel=0,pix_in=16'h1234;
    wire [15:0] pix_out;
    video_ai_frontend #(.RESULT_TTL(2)) dut(.*);
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task vs;
        begin
            @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);
            pix_vs=0;
        end
    endtask
    integer x,y;
    initial begin
        repeat(4) @(negedge cpu_clk);cpu_rstn=1;pix_rstn=1;cam_rstn=1;
        wr(8'h84,0);wr(8'h88,{16'd1,16'd2});
        wr(8'h8c,{16'd12,16'd15});wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);
        if(dut.box_class[0]!=0) $fatal(1,"OSD changed before frame boundary");
        vs();
        for(y=0;y<16;y=y+1) begin
            for(x=0;x<20;x=x+1) begin
                @(negedge pix_clk);pix_de=1;
                #1;
                if(x==2 && y==1 && pix_out!=16'h07e0) $fatal(1,"box border");
                if(x==5 && y==4 && pix_out!=16'hffff) $fatal(1,"class label B");
                if(x==19 && pix_out!=pix_in) $fatal(1,"outside box changed");
            end
            @(negedge pix_clk);pix_de=0;
            repeat(2) @(negedge pix_clk);
        end
        vs();vs();
        if(dut.age!=2) $fatal(1,"result TTL did not expire");
        $display("VIDEO_FRONTEND_PASS frame mailbox, RGB box, label, TTL");
        $finish;
    end
    initial begin repeat(5000) @(posedge cpu_clk);$fatal(1,"video timeout");end
endmodule
