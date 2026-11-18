`timescale 1ns/1ps
module tb_game_target_lock;
    reg cpu_clk=0,pix_clk=0,cam_clk=0,game_clk=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 pix_clk=~pix_clk;
    always #9 cam_clk=~cam_clk;
    always #11 game_clk=~game_clk;
    reg cpu_rstn=0,pix_rstn=0,cam_rstn=0,rst=1;
    reg wr_en=0,rd_en=0,cam_vs=0,cam_de=0,pix_vs=0,pix_de=0;
    reg [7:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    reg [15:0] cam_pixel=0,pix_in=16'h1234;
    wire [31:0] rd_data;
    wire [15:0] pix_out;
    wire result_commit,result_valid;
    wire [7:0] result_class_id;
    wire [3:0] result_count;
    wire detect_event,bin_valid;
    wire [8:0] business_payload;
    wire [2:0] bin_code;
    reg [3:0] key_event=0,servo_open_state=0;
    wire [3:0] servo_trigger;
    wire voice_valid;
    wire [2:0] voice_asset_id;
    wire [127:0] snapshot;
    reg hold_source=1;
    reg [1:0] hold_sync=3;
    wire quiz_hold=hold_sync[1];
    integer prompts=0;
    always @(posedge game_clk) begin
        if(rst) hold_source<=1;
        else hold_source<=snapshot[2:0]!=0;
        if(voice_valid && voice_asset_id==1) prompts<=prompts+1;
    end
    always @(posedge cpu_clk) begin
        if(!cpu_rstn) hold_sync<=3;
        else hold_sync<={hold_sync[0],hold_source};
    end
    video_ai_frontend #(.FOUR_BIN_CLASSES(1),.GAME_TARGET_LOCK(1)) dut(.*);
    result_event_cdc #(.W(9)) cdc(
        .sclk(cpu_clk),.srst(!cpu_rstn),.event_in(result_commit),
        .payload_in({result_valid,result_class_id}),.overflow(),
        .dclk(game_clk),.drst(rst),.event_out(detect_event),.payload_out(business_payload));
    yolo_class_to_bin #(.FOUR_BIN_CLASSES(1)) mapping(
        .result_valid(business_payload[8]),.result_class_id(business_payload[7:0]),.*);
    trash_quiz_controller quiz(.clk(game_clk),.start_ready(1'b1),.*);
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task check_status(input [31:0] mask,input [31:0] expected);
        begin
            rd_en=1;rd_addr=8'h98;#1;
            if((rd_data&mask)!=expected) $fatal(1,"firmware round-status mismatch got=%h",rd_data);
            rd_en=0;
        end
    endtask
    task stage(input integer cls);
        begin
            wr(8'h84,0);wr(8'h88,{16'd100,16'd200});
            wr(8'h8c,{16'd200,16'd300});wr(8'h90,32'h80000000|cls);
        end
    endtask
    task vs;
        begin
            repeat(5) @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);pix_vs=0;
            repeat(6) @(negedge cpu_clk);
        end
    endtask
    initial begin
        repeat(8) @(negedge cpu_clk);
        cpu_rstn=1;pix_rstn=1;cam_rstn=1;rst=0;
        repeat(20) @(negedge cpu_clk);
        // No capture: replayed or stale detection cannot start a round.
        stage(2);wr(8'h94,1);
        if(result_commit || dut.round_locked) $fatal(1,"accepted result without new capture");
        wr(8'h74,1);wr(8'h94,1);
        if(!result_commit || !dut.round_locked || result_class_id!=2) $fatal(1,"first target not latched");
        check_status(32'h2,32'h2);
        // Immediate lock must cover the result CDC round trip.
        stage(0);wr(8'h94,1);
        if(result_commit || result_class_id!=2) $fatal(1,"changed target before busy feedback");
        repeat(35) @(negedge game_clk);
        if(snapshot[2:0]!=1 || snapshot[105:104]!=1 || prompts!=1) $fatal(1,"wrong locked question");
        check_status(32'he,32'h6);
        // Capture and infer while busy: do not change display or answer.
        wr(8'h74,1);wr(8'h94,1);
        if(result_commit || result_class_id!=2) $fatal(1,"busy capture replaced target");
        @(negedge game_clk);key_event=1;
        @(negedge game_clk);key_event=0;
        if(servo_trigger!=4'b0010 || voice_asset_id!=3) $fatal(1,"wrong answer failed to open correct red bin");
        servo_open_state=4'b0010;
        repeat(30) @(negedge game_clk);
        if(!dut.round_locked || snapshot[2:0]!=2) $fatal(1,"unlocked during servo operation");
        servo_open_state=0;
        repeat(20) @(negedge game_clk);
        if(snapshot[2:0]!=0 || dut.round_locked || !dut.clear_pending) $fatal(1,"round release/backpressure failed");
        check_status(32'he,32'h8);
        // The original OSD payload is still unacknowledged: clear must wait.
        wr(8'h94,1);
        if(result_commit) $fatal(1,"late previous-round result accepted");
        vs(); // first target reaches pixels and clears mailbox backpressure
        repeat(10) @(negedge cpu_clk);
        if(!dut.payload_force_clear || dut.clear_pending) $fatal(1,"pending clear not sent");
        vs();
        if(dut.box_class[0][31] || dut.miss_pending) $fatal(1,"round-end clear waited for miss TTL");
        check_status(32'he,32'h0);
        wr(8'h94,1);
        if(result_commit) $fatal(1,"stale capture starts next round");
        // Multi-target and hand-only commits must not create a game answer.
        wr(8'h74,1);stage(4);wr(8'h94,1);
        if(result_commit) $fatal(1,"hand was routed as garbage");
        stage(0);wr(8'h84,1);wr(8'h90,32'h80000001);wr(8'h94,1);
        if(result_commit) $fatal(1,"ambiguous multi-target commit accepted");
        wr(8'h90,0);stage(3);wr(8'h94,1);
        if(!result_commit || result_class_id!=3 || result_count!=1) $fatal(1,"fresh next target rejected");
        vs();repeat(30) @(negedge game_clk);
        if(snapshot[105:104]!=2 || prompts!=2) $fatal(1,"next question not gray");
        // Reset clears both the local lock and displayed target.
        cpu_rstn=0;pix_rstn=0;rst=1;
        repeat(8) @(negedge cpu_clk);
        if(dut.round_locked || result_valid || dut.box_class[0][31]) $fatal(1,"reset retained target");
        $display("TEST_PASS game_target_lock question/OSD/servo/CDC/stale/backpressure/reset");
        $finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
