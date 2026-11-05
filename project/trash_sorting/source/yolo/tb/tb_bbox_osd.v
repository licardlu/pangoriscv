`timescale 1ns/1ps
module tb_bbox_osd;
    reg cpu_clk=0,pix_clk=0,cam_clk=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 pix_clk=~pix_clk;
    always #9 cam_clk=~cam_clk;
    reg cpu_rstn=0,pix_rstn=0,cam_rstn=0;
    reg wr_en=0;
    reg [7:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    wire [31:0] rd_data;
    reg cam_vs=0,cam_de=0,pix_vs=0,pix_de=0;
    reg [15:0] cam_pixel=0,pix_in=16'h1234;
    wire [15:0] pix_out;
    wire result_commit,result_valid;
    wire [7:0] result_class_id;
    wire [3:0] result_count;
    // Six display frames are used here so expiry is practical in a short sim.
    video_ai_frontend #(.RESULT_TTL(6),.VIEW_X1(80),.VIEW_X2(300)) dut(.*);
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task frame_start;
        begin
            @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);
            pix_vs=0;
        end
    endtask
    task empty_frame;
        begin
            @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);
            pix_vs=0;
        end
    endtask
    task check_pixel(input [15:0] px,input [15:0] py,input [15:0] expected);
        begin
            force dut.x=px;
            force dut.y=py;
            @(negedge pix_clk);pix_de=1;#1;
            if(pix_out!==expected)$fatal(1,"unexpected OSD pixel at (%0d,%0d): %h",px,py,pix_out);
            pix_de=0;
            release dut.x;
            release dut.y;
        end
    endtask
    initial begin
        repeat(4) @(negedge cpu_clk);cpu_rstn=1;pix_rstn=1;cam_rstn=1;
        // No recognition means the camera pixel passes through, including at
        // the old debug-guide coordinates. GUIDE_ENABLE defaults to zero.
        check_pixel(16'd480,16'd200,pix_in);

        wr(8'h84,0);wr(8'h88,{16'd100,16'd100});
        wr(8'h8c,{16'd199,16'd199});wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        check_pixel(16'd100,16'd100,16'hfd20);
        check_pixel(16'd199,16'd199,16'hfd20);
        check_pixel(16'd200,16'd100,pix_in);
        check_pixel(16'd480,16'd200,pix_in);

        // A slow inference has not reported an empty scene. Preserve the box
        // even when the gap between commits exceeds RESULT_TTL.
        repeat(12) empty_frame();
        check_pixel(16'd100,16'd100,16'hfd20);

        // The first empty commit starts a timeout, without erasing the box.
        wr(8'h90,32'h0);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        repeat(4) empty_frame();
        check_pixel(16'd100,16'd100,16'hfd20);
        check_pixel(16'd480,16'd200,pix_in);
        // A repeated empty commit advances, rather than resetting, the timer.
        wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        check_pixel(16'd100,16'd100,16'hfd20);
        // The sixth frame after the first empty result clears it completely.
        // The board wrapper selects 120 frames at 60 Hz for two seconds.
        empty_frame();
        check_pixel(16'd100,16'd100,pix_in);
        check_pixel(16'd480,16'd200,pix_in);
        // A target wholly outside the displayed crop must not create a guide.
        wr(8'h88,{16'd100,16'd10});wr(8'h8c,{16'd199,16'd40});
        wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        check_pixel(16'd480,16'd200,pix_in);

        // Valid detection cancels a pending timeout, and remains visible
        // through an arbitrarily slow subsequent inference.
        wr(8'h88,{16'd100,16'd100});wr(8'h8c,{16'd199,16'd199});
        wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        wr(8'h90,32'h0);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        repeat(3) empty_frame();
        check_pixel(16'd100,16'd100,16'hfd20);
        wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        repeat(12) empty_frame();
        check_pixel(16'd100,16'd100,16'hfd20);
        // A replacement result atomically moves the box and changes its color.
        wr(8'h88,{16'd110,16'd150});wr(8'h8c,{16'd209,16'd249});
        wr(8'h90,32'h80000003);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        check_pixel(16'd100,16'd100,pix_in);
        check_pixel(16'd150,16'd110,16'h001f);
        wr(8'h90,32'h0);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);frame_start();
        repeat(6) empty_frame();
        check_pixel(16'd150,16'd110,pix_in);
        check_pixel(16'd480,16'd200,pix_in);
        $display("BBOX_OSD_RTL_PASS slow inference hold + empty timeout + no empty refresh + valid recovery + guide disabled + replacement");
        $finish;
    end
    initial begin repeat(200000) @(posedge cpu_clk);$fatal(1,"timeout");end
endmodule
