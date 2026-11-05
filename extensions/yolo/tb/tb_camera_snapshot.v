`timescale 1ns/1ps
module tb_camera_snapshot;
    reg cpu_clk=0,cam_clk=0,cpu_rstn=0,cam_rstn=0,request=0,vsync=0,de=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 cam_clk=~cam_clk;
    reg [15:0] read_address=0,pixel=0;
    wire [15:0] read_data,frame_id;
    wire busy,ready,error;
    camera_snapshot #(.IN_W(8),.IN_H(4),.STEP(2)) dut(.*);
    integer x,y,i;
    task frame(input integer bias);
        begin
            @(negedge cam_clk);vsync=1;
            repeat(3) @(negedge cam_clk);
            vsync=0;
            repeat(2) @(negedge cam_clk);
            for(y=0;y<4;y=y+1) begin
                for(x=0;x<8;x=x+1) begin
                    de=1;pixel=bias+y*8+x;@(negedge cam_clk);
                end
                de=0;repeat(3) @(negedge cam_clk);
            end
        end
    endtask
    initial begin
        repeat(4) @(negedge cpu_clk);cpu_rstn=1;cam_rstn=1;
        request=1;@(negedge cpu_clk);request=0;
        repeat(5) @(negedge cam_clk);
        frame(100);
        wait(ready);
        if(error || busy) $fatal(1,"capture status");
        frame(200); // Unrequested frames must not overwrite the frozen buffer.
        for(i=0;i<8;i=i+1) begin
            @(negedge cpu_clk);read_address=i;
            repeat(2) @(negedge cpu_clk);
            if(read_data!==100+(i/4)*16+(i%4)*2)
                $fatal(1,"snapshot %0d got %0d",i,read_data);
        end
        $display("SNAPSHOT_PASS decimation, frozen ownership, synchronous reads");
        $finish;
    end
    initial begin repeat(2000) @(posedge cpu_clk);$fatal(1,"snapshot timeout");end
endmodule
