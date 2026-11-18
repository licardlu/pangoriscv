`timescale 1ns/1ps
module tb_stereo_snapshot;
    reg cpu=0,lclk=0,rclk=0,rst=0,request=0,pair_mode=0;
    always #5 cpu=~cpu;
    always #7 lclk=~lclk;
    always #11 rclk=~rclk;
    reg lvs=0,lde=0,rvs=0,rde=0;
    reg [15:0] lp=0,rp=0,address=0;
    reg right_bad=0,right_stopped=0;
    wire [15:0] data,lid,rid;
    wire busy,ready,error,paired;
    wire [31:0] lt,rt;
    reg [31:0] old_gray=0;
    always @(negedge cpu)begin
        if(!rst)old_gray=0;
        else begin
            if(!$onehot0(dut.gray_ticks^old_gray))$fatal(1,"Gray timestamp changed multiple bits");
            if(dut.gray_ticks!==((dut.ticks>>1)^dut.ticks))$fatal(1,"Gray timestamp mismatched counter");
            old_gray=dut.gray_ticks;
        end
    end
    camera_pair_snapshot #(.IN_W(8),.IN_H(4),.STEP(2),.TIMEOUT_CYCLES(1000)) dut(
        .cpu_clk(cpu),.cpu_rstn(rst),.request(request),.pair_mode(pair_mode),
        .read_address(address),.read_data(data),.busy(busy),.ready(ready),.error(error),
        .captured_pair(paired),.frame_id(lid),.right_frame_id(rid),
        .left_frame_tick(lt),.right_frame_tick(rt),
        .left_clk(lclk),.left_rstn(rst),.left_vs(lvs),.left_de(lde),.left_pixel(lp),
        .right_clk(rclk),.right_rstn(rst),.right_vs(rvs),.right_de(rde),.right_pixel(rp));
    function automatic [15:0] color(input integer side,x,y);
        color=side ? (16'h8410+x*97+y*201) : (16'h1234+x*73+y*109);
    endfunction
    function automatic [7:0] gray(input [15:0] p);
        integer r,g,b;
        begin
            r=((p>>11)&31)*8+((p>>13)&7);
            g=((p>>5)&63)*4+((p>>9)&3);
            b=(p&31)*8+((p>>2)&7);
            gray=(r+g*2+b)/4;
        end
    endfunction
    integer lx,ly,rx,ry;
    initial forever begin
        wait(rst);
        @(negedge lclk);lvs=1;lde=0;
        repeat(4)@(negedge lclk);
        lvs=0;
        @(negedge lclk);
        for(ly=0;ly<4;ly=ly+1)begin
            for(lx=0;lx<8;lx=lx+1)begin lde=1;lp=color(0,lx,ly);@(negedge lclk);end
            lde=0;repeat(3)@(negedge lclk);
        end
        repeat(4)@(negedge lclk);
    end
    initial begin
        #51;
        forever begin
            wait(rst && !right_stopped);
            @(negedge rclk);rvs=1;rde=0;
            repeat(4)@(negedge rclk);
            rvs=0;
            @(negedge rclk);
            for(ry=0;ry<4;ry=ry+1)begin
                for(rx=0;rx<(right_bad?7:8);rx=rx+1)begin
                    rde=1;rp=color(1,rx,ry);@(negedge rclk);
                end
                rde=0;repeat(3)@(negedge rclk);
            end
            repeat(4)@(negedge rclk);
        end
    end
    task launch(input integer is_pair);
        begin
            @(negedge cpu);pair_mode=is_pair;request=1;
            @(negedge cpu);request=0;
        end
    endtask
    task check_image(input integer is_pair);
        integer a,x,y;
        reg [15:0] expected;
        begin
            for(a=0;a<8;a=a+1)begin
                @(negedge cpu);address=a;
                repeat(2)@(negedge cpu);
                x=(a%4)*2;y=(a/4)*2;
                expected=is_pair?{gray(color(1,x,y)),gray(color(0,x,y))}:color(0,x,y);
                if(data!==expected)$fatal(1,"pixel a=%0d pair=%0d got=%h expected=%h",a,is_pair,data,expected);
            end
            address=16'hffff;repeat(2)@(negedge cpu);
            if(data!==0)$fatal(1,"out-of-range read not zero");
        end
    endtask
    reg [15:0] saved_lid,saved_rid;
    initial begin
        // RGB must remain usable when the second camera produces no frames.
        right_stopped=1;
        repeat(8)@(negedge cpu);rst=1;
        launch(0);wait(busy);
        launch(1); // ignored while RGB capture is pending
        wait(ready || error);
        if(error || paired || busy)$fatal(1,"RGB capture state");
        check_image(0);
        saved_lid=lid;repeat(400)@(negedge cpu);
        if(lid!=saved_lid)$fatal(1,"immutable RGB metadata changed");
        check_image(0);
        right_stopped=0;
        launch(1);wait(ready || error);
        if(error || !paired || busy || lt==0 || rt==0)$fatal(1,"pair capture state");
        check_image(1);
        saved_lid=lid;saved_rid=rid;repeat(500)@(negedge cpu);
        if(lid!=saved_lid || rid!=saved_rid)$fatal(1,"pair metadata changed");
        check_image(1);
        launch(0);wait(ready || error);if(error || paired)$fatal(1,"back to RGB");
        check_image(0);
        right_bad=1;repeat(500)@(negedge cpu);
        launch(1);wait(ready || error);
        if(!error || ready || busy)$fatal(1,"malformed right frame accepted");
        right_bad=0;repeat(500)@(negedge cpu);
        launch(1);wait(ready || error);if(error)$fatal(1,"recovery after malformed frame");
        check_image(1);
        right_stopped=1;repeat(500)@(negedge cpu);
        launch(1);wait(error);
        if(!busy || ready)$fatal(1,"timeout did not quarantine");
        right_stopped=0;launch(0);repeat(600)@(negedge cpu);
        if(!busy || ready || !error)$fatal(1,"late frame escaped quarantine");
        rst=0;repeat(10)@(negedge cpu);rst=1;
        launch(0);wait(ready || error);if(error)$fatal(1,"reset recovery");
        check_image(0);
        $display("TEST_PASS stereo_snapshot RGB/right-frame-off/pair/mode/immutable/busy/malformed/timeout/late/reset");
        $finish;
    end
    initial begin #300000;$fatal(1,"stereo simulation timeout");end
endmodule
