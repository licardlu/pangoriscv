`timescale 1ns/1ps
module tb_stereo_frontend;
    reg cpu=0,lclk=0,rclk=0,rst=0;
    always #5 cpu=~cpu;
    always #7 lclk=~lclk;
    always #11 rclk=~rclk;
    reg wr=0,rd=0,vs=0;
    reg [7:0] wa=0,ra=0;
    reg [31:0] wd=0;
    wire [31:0] data;
    wire [2:0] automatic_request;
    reg blocked=0;
    video_ai_frontend #(.STEREO_CAPTURE(1),.GAME_TARGET_LOCK(1)) dut(
        .cpu_clk(cpu),.cpu_rstn(rst),.quiz_hold(1'b0),
        .wr_en(wr),.wr_addr(wa),.wr_data(wd),.rd_en(rd),.rd_addr(ra),.rd_data(data),
        .cam_clk(lclk),.cam_rstn(rst),.cam_vs(1'b0),.cam_de(1'b0),.cam_pixel(16'b0),
        .right_cam_clk(rclk),.right_cam_rstn(rst),.right_cam_vs(1'b0),
        .right_cam_de(1'b0),.right_cam_pixel(16'b0),
        .automatic_request(automatic_request),.automatic_blocked_async(blocked),
        .pix_clk(cpu),.pix_rstn(rst),.pix_vs(vs),.pix_de(1'b0),.pix_in(16'b0),.pix_out());
    task write(input [7:0] address,input [31:0] value);
        begin
            @(negedge cpu);wa=address;wd=value;wr=1;
            @(negedge cpu);wr=0;repeat(3)@(negedge cpu);
        end
    endtask
    task read(input [7:0] address,input [31:0] expected);
        begin
            @(negedge cpu);ra=address;rd=1;#1;
            if(data!==expected)$fatal(1,"MMIO %h got=%h wanted=%h",address,data,expected);
            @(negedge cpu);rd=0;
        end
    endtask
    initial begin
        repeat(8)@(negedge cpu);rst=1;
        force dut.stereo_capture.capture.ready=1;
        force dut.stereo_capture.capture.captured_pair=1;
        force dut.stereo_capture.capture.frame_id=16'h1234;
        force dut.stereo_capture.capture.right_frame_id=16'h5678;
        force dut.stereo_capture.capture.left_frame_tick=32'h11223344;
        force dut.stereo_capture.capture.right_frame_tick=32'h55667788;
        dut.stereo_capture.capture.bank0[0]=8'h12;dut.stereo_capture.capture.bank1[0]=8'h34;
        dut.stereo_capture.capture.bank0[1]=8'h56;dut.stereo_capture.capture.bank1[1]=8'h78;
        write(8'h78,0);
        read(8'h7c,32'h3412);read(8'h7c,32'h3412);
        if(dut.snapshot_address!=0)$fatal(1,"legacy read advanced");
        read(8'hbc,32'h3412);read(8'hbc,32'h7856);
        write(8'h78,16'hff00);read(8'h7c,32'h56781234);
        write(8'h78,16'hff01);read(8'h7c,32'h11223344);
        write(8'h78,16'hff02);read(8'h7c,32'h55667788);
        write(8'h78,16'hff03);read(8'h7c,32'h53545031);
        read(8'h80,32'h1234001a);
        write(8'h74,32'ha0);
        if(automatic_request!=4)$fatal(1,"auto idle request must be one-hot");
        blocked=1;repeat(4)@(negedge cpu);
        write(8'h78,16'hff04);read(8'h7c,6);
        // The automatic request does not count as capture eligibility.
        if(dut.capture_eligible)$fatal(1,"page command armed game capture");
        // RGB capture authorizes commit; paired validation can preserve this
        // authorization, while an ordinary calibration capture clears it.
        write(8'h74,1);if(!dut.capture_eligible)$fatal(1,"RGB not eligible");
        force dut.cap_busy=0;
        write(8'h74,7);if(!dut.capture_eligible)$fatal(1,"validation lost RGB eligibility");
        write(8'h74,3);if(dut.capture_eligible)$fatal(1,"diagnostic eligible");
        $display("TEST_PASS stereo_frontend pixels/stream/metadata/status/page/game-eligibility");
        $finish;
    end
    initial begin #100000;$fatal(1,"frontend timeout");end
endmodule
