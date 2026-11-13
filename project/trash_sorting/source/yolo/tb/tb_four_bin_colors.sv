`timescale 1ns/1ps
module tb_four_bin_colors;
    wire quiz_hold=1'b0;
    parameter integer FOUR=1;
    reg cpu_clk=0,pix_clk=0,cam_clk=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 pix_clk=~pix_clk;
    always #9 cam_clk=~cam_clk;
    reg cpu_rstn=0,pix_rstn=0,cam_rstn=0,wr_en=0,rd_en=0;
    reg [7:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    wire [31:0] rd_data;
    reg cam_vs=0,cam_de=0,pix_vs=0,pix_de=0;
    reg [15:0] cam_pixel=0,pix_in=16'h1234;
    wire [15:0] pix_out;
    wire result_commit,result_valid,bin_valid;
    wire [7:0] result_class_id;
    wire [3:0] result_count;
    wire [2:0] bin_code;
    video_ai_frontend #(.FOUR_BIN_CLASSES(FOUR),.OSD_TEXT(0)) dut(.*);
    yolo_class_to_bin #(.FOUR_BIN_CLASSES(FOUR)) mapping(
        .result_valid(result_valid),.result_class_id(result_class_id),
        .bin_valid(bin_valid),.bin_code(bin_code));
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task pixel(input [15:0] px,input [15:0] py,input [15:0] expected);
        begin
            force dut.x=px;force dut.y=py;
            @(negedge pix_clk);pix_de=1;#1;
            if(pix_out!==expected) $fatal(1,"schema=%0d class=%0d at %0d,%0d got=%h expected=%h",FOUR,cid,px,py,pix_out,expected);
            pix_de=0;release dut.x;release dut.y;
        end
    endtask
    integer cid,px,py;
    reg valid;
    reg [2:0] expected_bin;
    reg [15:0] color;
    initial begin
        repeat(4) @(negedge cpu_clk);cpu_rstn=1;pix_rstn=1;cam_rstn=1;
        wr(8'h88,{16'd10,16'd10});wr(8'h8c,{16'd49,16'd119});
        for(cid=0;cid<256;cid=cid+1) begin
            valid=cid<(FOUR?4:6);
            expected_bin=!valid?0:cid==0?1:FOUR&&cid==2?2:FOUR&&cid==3?3:4;
            color=expected_bin==1?16'h07e0:expected_bin==2?16'hf800:expected_bin==3?16'h8410:16'h001f;
            wr(8'h90,32'h80000000|cid);wr(8'h94,1);
            if(!result_valid || bin_valid!==valid || bin_code!==expected_bin)
                $fatal(1,"schema/bin mismatch class=%0d bin=%0d",cid,bin_code);
            repeat(5) @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);pix_vs=0;
            repeat(5) @(negedge cpu_clk);
            pixel(10,10,valid?color:pix_in);
            pixel(119,49,valid?color:pix_in);
            pixel(9,10,pix_in);pixel(120,49,pix_in);
            if(valid) begin
                // Entire old two-line label region stays camera pixels.
                for(py=15;py<31;py=py+1)
                    for(px=15;px<63;px=px+1) pixel(px,py,pix_in);
            end
        end
        $display("TEST_PASS four_bin_colors schema=%0d all256 IDs, four bin/color pairs, no text, invalid IDs rejected without truncation",FOUR);
        $finish;
    end
    initial begin #2000000;$fatal(1,"color test timeout");end
endmodule
