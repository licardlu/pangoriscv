`timescale 1ns/1ps
module tb_yolo_result_commit;
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
    wire bin_valid;
    wire [2:0] bin_code;
    video_ai_frontend dut(.*);
    yolo_class_to_bin mapping(.result_valid(result_valid),.result_class_id(result_class_id),
        .bin_valid(bin_valid),.bin_code(bin_code));
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task acknowledge;
        begin
            repeat(5) @(negedge pix_clk);
            pix_vs=1;
            repeat(3) @(negedge pix_clk);
            pix_vs=0;
            repeat(5) @(negedge cpu_clk);
            rd_addr=8'h98;#1;
            if(rd_data[0]) $fatal(1,"mailbox failed to acknowledge at frame boundary");
        end
    endtask
    initial begin
        repeat(4) @(negedge cpu_clk);
        if(result_commit || result_valid || result_count) $fatal(1,"metadata reset failed");
        cpu_rstn=1;pix_rstn=1;cam_rstn=1;
        wr(8'h84,0);wr(8'h90,32'h80000005);
        wr(8'h84,3);wr(8'h90,32'h80000000);
        if(result_commit || result_valid || result_count) $fatal(1,"staging leaked a result");
        wr(8'h94,0);
        if(result_commit) $fatal(1,"commit bit 0 created a pulse");
        wr(8'h94,1);
        if(!result_commit || !result_valid || result_count!=2 || result_class_id!=5 || !bin_valid || bin_code!=1)
            $fatal(1,"multi-slot result count or priority failed");
        @(negedge cpu_clk);
        if(result_commit) $fatal(1,"commit was not a single CPU clock pulse");
        wr(8'h94,1);
        if(result_commit || result_count!=2 || result_class_id!=5) $fatal(1,"busy commit was accepted");
        acknowledge();

        wr(8'h84,0);wr(8'h90,0);
        wr(8'h84,3);wr(8'h90,0);
        wr(8'h84,6);wr(8'h90,32'h80000000);
        wr(8'h94,1);
        if(!result_commit || !result_valid || result_count!=1 || result_class_id!=0 || bin_code!=4)
            $fatal(1,"first valid slot search or organic mapping failed");
        acknowledge();
        wr(8'h84,6);wr(8'h90,0);wr(8'h94,1);
        if(!result_commit || result_valid || result_count!=0 || result_class_id!=0 || bin_valid || bin_code!=0)
            $fatal(1,"empty snapshot contract failed");
        acknowledge();
        wr(8'h84,2);wr(8'h90,32'h800000ff);wr(8'h94,1);
        if(!result_commit || !result_valid || result_count!=1 || result_class_id!=255 || bin_valid)
            $fatal(1,"unknown raw class was truncated into a supported bin");
        $display("TEST_PASS yolo_result_commit accepted/staged/busy/empty + first valid + raw class + mapping");
        $finish;
    end
    initial begin #100000;$fatal(1,"timeout");end
endmodule
