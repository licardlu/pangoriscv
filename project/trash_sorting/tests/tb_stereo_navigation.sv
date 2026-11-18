`timescale 1ns/1ps
module tb_stereo_navigation;
    reg clk=0,rst=1,next_page=0,single=0,long_press=0,debug_page=0;
    reg [2:0] automatic_request=1;
    wire [1:0] page;
    wire blocked,toggle;
    always #5 clk=~clk;
    media_page_router #(.RESET_PAGE(2),.AUTO_ONEHOT(1)) dut(.clk(clk),.rst(rst),.next_page(next_page),
        .long_press(long_press),.debug_page_async(debug_page),
        .toggle_recognition(single),.automatic_request_async(automatic_request),
        .automatic_blocked(blocked),.page(page),.benchmark_start_toggle(toggle));
    task set_auto(input [1:0] value,input [1:0] expected);
        begin
            @(negedge clk);automatic_request=3'b001<<value;
            repeat(6)@(negedge clk);
            if(page!==expected)$fatal(1,"auto %d wanted=%d got=%d",value,expected,page);
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        if(page!=2)$fatal(1,"manual fallback must start in idle animation");
        next_page=1;@(negedge clk);next_page=0;
        if(page!=1 || !toggle)$fatal(1,"idle double click must enter score");
        next_page=1;@(negedge clk);next_page=0;
        if(page!=2)$fatal(1,"score double click must return to animation");
        set_auto(0,2);
        set_auto(2,2);set_auto(1,0);set_auto(2,2);
        single=1;@(negedge clk);single=0;
        if(page!=0 || !blocked)$fatal(1,"single priority");
        // Deliberately extend skewed samples for several clocks: no invalid
        // one-hot value may rearm automatic control after a manual override.
        automatic_request=0;repeat(6)@(negedge clk);
        if(page!=0 || !blocked)$fatal(1,"all-zero CDC sample rearmed auto");
        automatic_request=3;repeat(6)@(negedge clk);
        if(page!=0 || !blocked)$fatal(1,"multi-hot CDC sample rearmed auto");
        automatic_request=7;repeat(6)@(negedge clk);
        if(page!=0 || !blocked)$fatal(1,"invalid CDC sample changed manual priority");
        set_auto(2,0);set_auto(1,0);
        set_auto(0,0);if(blocked)$fatal(1,"auto disable did not rearm");
        next_page=1;@(negedge clk);next_page=0;
        if(page!=1 || toggle)$fatal(1,"double score");
        set_auto(2,1);
        next_page=1;@(negedge clk);next_page=0;
        if(page!=2)$fatal(1,"next animation");
        set_auto(1,2);
        set_auto(0,2);set_auto(1,0);
        debug_page=1;repeat(5)@(negedge clk);
        if(page!=1)$fatal(1,"debug score priority");
        $display("TEST_PASS stereo_navigation auto-idle/wake/manual-priority/score/rearm");
        $finish;
    end
    initial begin #20000;$fatal(1,"navigation timeout");end
endmodule
