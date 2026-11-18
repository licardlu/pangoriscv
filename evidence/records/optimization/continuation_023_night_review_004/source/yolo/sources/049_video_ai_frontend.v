// Camera snapshot + frame-boundary OSD mailbox. The 8-box payload remains
// stable across CDC until the pixel domain acknowledges it.
`timescale 1ns/1ps
module video_ai_frontend #(
    parameter integer STEREO_CAPTURE=0,
    // Number of display frames for which the last detection remains visible
    // after the first explicitly empty inference. Slow inference alone must
    // not erase a valid result. The board wrapper sets a frame-rate-specific
    // TTL: 60 frames at 30 Hz, or 120 frames at 60 Hz, gives two seconds.
    parameter integer RESULT_TTL=60,
    // Product view communicates only the bin, through its border color.
    parameter integer OSD_TEXT=0,
    parameter integer FOUR_BIN_CLASSES=0,
    parameter integer GAME_TARGET_LOCK=0,
    parameter integer OSD_BORDER=4,
    // Optional debug capture guide. Keep it disabled in normal operation so
    // expiry removes every rectangle rather than showing a false detection.
    parameter integer GUIDE_ENABLE=0,
    // Centered 320x320 capture guide for the no-detection state. These
    // defaults match the 1280x720 HDMI raster and can be overridden by a
    // board-level wrapper without changing the MMIO protocol.
    parameter integer GUIDE_X1=480,
    parameter integer GUIDE_Y1=200,
    parameter integer GUIDE_X2=799,
    parameter integer GUIDE_Y2=519,
    // Visible source range after an optional downstream center crop. A box
    // entirely outside it must not suppress the on-screen acquisition guide.
    parameter integer VIEW_X1=0,
    parameter integer VIEW_X2=1279,
    parameter integer VIEW_Y1=0,
    parameter integer VIEW_HEIGHT=720,
    parameter integer SOURCE_HEIGHT=720,
    parameter [15:0] GUIDE_COLOR=16'h07e0
) (
    input wire cpu_clk,cpu_rstn,
    input wire quiz_hold,
    input wire wr_en,rd_en,
    input wire [7:0] wr_addr,rd_addr,
    input wire [31:0] wr_data,
    output reg [31:0] rd_data,
    input wire cam_clk,cam_rstn,cam_vs,cam_de,
    input wire [15:0] cam_pixel,
    input wire right_cam_clk,right_cam_rstn,right_cam_vs,right_cam_de,
    input wire [15:0] right_cam_pixel,
    // Registered one-hot CDC: disabled/recognition/animation. The receiver
    // ignores all-zero/multi-hot samples instead of decoding a transient page.
    output reg [2:0] automatic_request,
    input tri0 automatic_blocked_async,
    input wire pix_clk,pix_rstn,pix_vs,pix_de,
    input wire [15:0] pix_in,
    output reg [15:0] pix_out,
    // CPU-domain metadata from accepted MMIO commits. result_commit pulses
    // for one cpu_clk cycle, including an accepted empty snapshot. The data
    // outputs remain stable until the next accepted commit. This is separate
    // from pixel-domain hold/expiry, so a transient miss need not end a quiz.
    output reg result_commit,
    output reg result_valid,
    output reg [7:0] result_class_id,
    output reg [3:0] result_count
);
    reg [15:0] snapshot_address;
    wire [15:0] snapshot_data,frame_id;
    wire cap_busy,cap_ready,cap_error;
    wire captured_pair;
    wire [15:0] right_frame_id;
    wire [31:0] left_frame_tick,right_frame_tick;
    (* ASYNC_REG="TRUE" *)reg [1:0] blocked_sync;
    generate if(STEREO_CAPTURE) begin: stereo_capture
    camera_pair_snapshot capture(
        .cpu_clk(cpu_clk),.cpu_rstn(cpu_rstn),
        .request(wr_en && wr_addr==8'h74 && wr_data[0]),.pair_mode(wr_data[1]),
        .read_address(snapshot_address),.read_data(snapshot_data),
        .busy(cap_busy),.ready(cap_ready),.error(cap_error),.captured_pair(captured_pair),
        .frame_id(frame_id),.right_frame_id(right_frame_id),
        .left_frame_tick(left_frame_tick),.right_frame_tick(right_frame_tick),
        .left_clk(cam_clk),.left_rstn(cam_rstn),.left_vs(cam_vs),.left_de(cam_de),.left_pixel(cam_pixel),
        .right_clk(right_cam_clk),.right_rstn(right_cam_rstn),.right_vs(right_cam_vs),
        .right_de(right_cam_de),.right_pixel(right_cam_pixel));
    end else begin: legacy_capture
    assign captured_pair=0;
    assign right_frame_id=0;
    assign left_frame_tick=0;
    assign right_frame_tick=0;
    camera_snapshot capture(
        .cpu_clk(cpu_clk),.cpu_rstn(cpu_rstn),
        .request(wr_en && wr_addr==8'h74 && wr_data[0]),
        .read_address(snapshot_address),.read_data(snapshot_data),
        .busy(cap_busy),.ready(cap_ready),.error(cap_error),.frame_id(frame_id),
        .cam_clk(cam_clk),.cam_rstn(cam_rstn),.vsync(cam_vs),.de(cam_de),.pixel(cam_pixel));
    end endgenerate
    reg [2:0] selected;
    reg [31:0] stage_xy1[0:7],stage_xy2[0:7],stage_class[0:7];
    reg [31:0] payload_xy1[0:7],payload_xy2[0:7],payload_class[0:7];
    wire payload_has_detection=payload_class[0][31] || payload_class[1][31] ||
        payload_class[2][31] || payload_class[3][31] || payload_class[4][31] ||
        payload_class[5][31] || payload_class[6][31] || payload_class[7][31];
    reg request_toggle,ack_toggle;
    reg round_locked,round_active_seen,capture_eligible,clear_pending;
    reg payload_force_clear;
    reg [1:0] ack_sync,request_sync;
    wire osd_busy=request_toggle!=ack_sync[1];
    reg [3:0] stage_count;
    reg [7:0] stage_first_class;
    integer k;
    // The firmware supplies score-ordered slots. Preserve that priority by
    // choosing the first valid slot; export the complete valid-slot count so
    // a caller can reject ambiguous multi-object input rather than guessing.
    always @(*) begin
        stage_count=0;
        stage_first_class=0;
        for(k=0;k<8;k=k+1) begin
            if(stage_class[k][31]) begin
                if(stage_count==0) stage_first_class=stage_class[k][7:0];
                stage_count=stage_count+1'b1;
            end
        end
    end
    integer i;
    always @(posedge cpu_clk) begin
        if(!cpu_rstn) begin
            snapshot_address<=0;selected<=0;request_toggle<=0;ack_sync<=0;
            result_commit<=0;result_valid<=0;result_class_id<=0;result_count<=0;
            round_locked<=0;round_active_seen<=0;capture_eligible<=0;
            clear_pending<=0;payload_force_clear<=0;
            automatic_request<=3'b001;blocked_sync<=0;
            for(i=0;i<8;i=i+1) begin
                stage_xy1[i]<=0;stage_xy2[i]<=0;stage_class[i]<=0;
                payload_xy1[i]<=0;payload_xy2[i]<=0;payload_class[i]<=0;
            end
        end else begin
            ack_sync<={ack_sync[0],ack_toggle};
            blocked_sync<={blocked_sync[0],automatic_blocked_async};
            result_commit<=0;
            if(GAME_TARGET_LOCK && round_locked) begin
                if(quiz_hold) round_active_seen<=1;
                if(round_active_seen && !quiz_hold) begin
                    round_locked<=0;round_active_seen<=0;
                    capture_eligible<=0;clear_pending<=1;
                end
            end
            // Consume exactly once at AXI address acceptance. The response
            // register retains this pixel while RREADY applies backpressure.
            if(rd_en && rd_addr==8'hbc && snapshot_address<57600)
                snapshot_address<=snapshot_address+1'b1;
            if(wr_en) case(wr_addr)
                8'h74:begin
                    if(wr_data[7] && wr_data[5:4]!=3)automatic_request<=3'b001<<wr_data[5:4];
                    if(wr_data[0] && !cap_busy && GAME_TARGET_LOCK)begin
                        if(!wr_data[1])capture_eligible<=!round_locked && !quiz_hold && !clear_pending;
                        else if(!wr_data[2])capture_eligible<=0;
                    end
                end
                8'h78:snapshot_address<=wr_data[15:0];
                8'h84:selected<=wr_data[2:0];
                8'h88:stage_xy1[selected]<=wr_data;
                8'h8c:stage_xy2[selected]<=wr_data;
                8'h90:stage_class[selected]<=wr_data;
                8'h94:if(wr_data[0] && !osd_busy &&
                         (!GAME_TARGET_LOCK || (!round_locked && !quiz_hold &&
                          !clear_pending && capture_eligible && stage_count<=1 &&
                          (stage_count==0 || stage_first_class<4)))) begin
                    request_toggle<=!request_toggle;
                    payload_force_clear<=0;
                    result_commit<=1;
                    result_valid<=stage_count!=0;
                    result_class_id<=stage_first_class;
                    result_count<=stage_count;
                    if(GAME_TARGET_LOCK) begin
                        capture_eligible<=0;
                        if(stage_count!=0) begin round_locked<=1;round_active_seen<=0;end
                    end
                    for(i=0;i<8;i=i+1) begin
                        payload_xy1[i]<=stage_xy1[i];
                        payload_xy2[i]<=stage_xy2[i];
                        payload_class[i]<=stage_class[i];
                    end
                end
                default:;
            endcase
            // Publish the round-end clear through the same stable mailbox.
            // Its force flag bypasses the ordinary transient-miss TTL.
            if(GAME_TARGET_LOCK && clear_pending && !osd_busy) begin
                request_toggle<=!request_toggle;payload_force_clear<=1;
                clear_pending<=0;
                result_commit<=1;result_valid<=0;result_count<=0;result_class_id<=0;
                for(i=0;i<8;i=i+1) begin
                    payload_xy1[i]<=0;payload_xy2[i]<=0;payload_class[i]<=0;
                end
            end
        end
    end
    // Exact RGB565 expansion followed by (channel*127+127)/255.
    // These small expressions are exhaustively checked over all 65536 colors.
    function [7:0] q5(input [4:0] value);
        q5={value,2'b00}+{5'b0,value[4:3]};
    endfunction
    function [7:0] q6(input [5:0] value);
        q6={value,1'b0}+value[5];
    endfunction
    always @(*) begin
        case(rd_addr)
            8'h7c:begin
                rd_data={16'b0,snapshot_data};
                if(STEREO_CAPTURE)case(snapshot_address)
                    16'hff00:rd_data={right_frame_id,frame_id};
                    16'hff01:rd_data=left_frame_tick;
                    16'hff02:rd_data=right_frame_tick;
                    16'hff03:rd_data=32'h53545031; // STP1; frame ticks, NOT exposure ticks
                    16'hff04:rd_data={29'b0,blocked_sync[1],
                        automatic_request[2]?2'd2:automatic_request[1]?2'd1:2'd0};
                    default:;
                endcase
            end
            8'hbc:rd_data=snapshot_address<57600 ?
                (captured_pair ? {16'b0,snapshot_data} :
                {8'b0,q5(snapshot_data[4:0]),q6(snapshot_data[10:5]),q5(snapshot_data[15:11])}) : 32'b0;
            8'h80:rd_data={frame_id,11'b0,(STEREO_CAPTURE!=0),captured_pair,cap_error,cap_ready,cap_busy};
            8'h98:rd_data={25'b0,(GAME_TARGET_LOCK ? payload_class[0][30:28] : 3'b0),
                           clear_pending,quiz_hold && (GAME_TARGET_LOCK!=0),
                           round_locked,osd_busy};
            default:rd_data=0;
        endcase
    end
    reg [31:0] box_xy1[0:7],box_xy2[0:7],box_class[0:7];
    reg [15:0] x,y;
    reg vs_d,de_d;
    wire [15:0] source_y;
    wire in_video = y>=VIEW_Y1 && y<VIEW_Y1+VIEW_HEIGHT;
    generate if(VIEW_Y1==0 && VIEW_HEIGHT==SOURCE_HEIGHT) begin: native_rows
        assign source_y=y;
    end else begin: scaled_rows
        localparam DEN=VIEW_HEIGHT>1 ? VIEW_HEIGHT-1 : 1;
        localparam STEP=(SOURCE_HEIGHT-1)/DEN;
        localparam REM=(SOURCE_HEIGHT-1)%DEN;
        reg [15:0] sy,error;
        assign source_y=sy;
        always @(posedge pix_clk) begin
            if(!pix_rstn || pix_vs) begin sy<=0;error<=0;end
            else if(de_d && !pix_de && in_video) begin
                if(error+REM>=DEN) begin sy<=sy+STEP+1;error<=error+REM-DEN;end
                else begin sy<=sy+STEP;error<=error+REM;end
            end
        end
    end endgenerate
    reg [15:0] age;
    reg miss_pending;
    integer j;
    always @(posedge pix_clk) begin
        if(!pix_rstn) begin
            request_sync<=0;ack_toggle<=0;x<=0;y<=0;vs_d<=0;de_d<=0;age<=RESULT_TTL;miss_pending<=0;
            for(j=0;j<8;j=j+1) begin box_xy1[j]<=0;box_xy2[j]<=0;box_class[j]<=0;end
        end else begin
            request_sync<={request_sync[0],request_toggle};vs_d<=pix_vs;de_d<=pix_de;
            if(pix_vs) begin x<=0;y<=0;end
            else begin
                if(pix_de) x<=x+1'b1;
                if(de_d && !pix_de) begin x<=0;y<=y+1'b1;end
            end
            if(pix_vs && !vs_d) begin
                if(request_sync[1]!=ack_toggle) begin
                    // A valid result atomically replaces the old box and
                    // cancels an empty-result timeout. Only an explicitly
                    // empty result starts that timeout; a slow inference is
                    // not evidence that the object disappeared.
                    if(payload_force_clear) begin
                        for(j=0;j<8;j=j+1) box_class[j]<=0;
                        age<=RESULT_TTL;miss_pending<=0;
                    end else if(payload_has_detection) begin
                        for(j=0;j<8;j=j+1) begin
                            box_xy1[j]<=payload_xy1[j];box_xy2[j]<=payload_xy2[j];
                            box_class[j]<=payload_class[j];
                        end
                        age<=0;
                        miss_pending<=0;
                    end else if(!miss_pending) begin
                        age<=0;
                        miss_pending<=1;
                    end else if(age<RESULT_TTL) begin
                        age<=age+1'b1;
                        if(age+1>=RESULT_TTL)
                            for(j=0;j<8;j=j+1) box_class[j]<=0;
                    end
                    ack_toggle<=request_sync[1];
                end else if(miss_pending && age<RESULT_TTL) begin
                    age<=age+1'b1;
                    if(age+1>=RESULT_TTL)
                        for(j=0;j<8;j=j+1) box_class[j]<=0;
                end
            end
        end
    end
    function [7:0] letter;
        input [2:0] category;
        input [3:0] index;
        begin
            case({category,index})
                7'h00:letter="B";7'h01:letter="I";7'h02:letter="O";
                7'h03:letter="D";7'h04:letter="E";7'h05:letter="G";
                7'h10:letter="C";7'h11:letter="A";7'h12:letter="R";7'h13:letter="D";
                7'h14:letter="B";7'h15:letter="R";7'h16:letter="D";
                7'h20:letter="G";7'h21:letter="L";7'h22:letter="A";
                7'h23:letter="S";7'h24:letter="S";
                7'h30:letter="M";7'h31:letter="E";7'h32:letter="T";
                7'h33:letter="A";7'h34:letter="L";
                7'h40:letter="P";7'h41:letter="A";7'h42:letter="P";
                7'h43:letter="E";7'h44:letter="R";
                7'h50:letter="P";7'h51:letter="L";7'h52:letter="A";
                7'h53:letter="S";7'h54:letter="T";7'h55:letter="I";7'h56:letter="C";
                default:letter=" ";
            endcase
        end
    endfunction
    function [7:0] bin_letter;
        input [2:0] category;
        input [3:0] index;
        begin
            if(category==0) begin
                case(index)
                    0:bin_letter="K";1:bin_letter="I";2:bin_letter="T";
                    3:bin_letter="C";4:bin_letter="H";5:bin_letter="E";
                    6:bin_letter="N";default:bin_letter=" ";
                endcase
            end else begin
                case(index)
                    0:bin_letter="R";1:bin_letter="E";2:bin_letter="C";
                    3:bin_letter="Y";4:bin_letter="C";5:bin_letter="L";
                    6:bin_letter="E";default:bin_letter=" ";
                endcase
            end
        end
    endfunction
    function [15:0] class_color;
        input [7:0] category;
        begin
            if(FOUR_BIN_CLASSES) case(category)
                0:class_color=16'h07e0; // kitchen / green
                1:class_color=16'h001f; // recyclable / blue
                2:class_color=16'hf800; // hazardous / red
                3:class_color=16'h8410; // other / gray
                default:class_color=0;
            endcase
            else class_color=category==0 ? 16'h07e0 : 16'h001f;
        end
    endfunction
    function supported_class;
        input [7:0] category;
        begin supported_class=FOUR_BIN_CLASSES ? category<4 : category<6;end
    endfunction
    function [34:0] glyph;
        input [7:0] ch;
        begin
            case(ch)
                "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
                "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
                "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
                "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
                "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
                "G":glyph=35'b01111_10000_10000_10111_10001_10001_01111;
                "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
                "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
                "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
                "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
                "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
                "N":glyph=35'b10001_11001_10101_10011_10001_10001_10001;
                "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
                "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
                "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
                "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
                "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
                "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
                default:glyph=0;
            endcase
        end
    endfunction
    integer b,dx,dy,column,row,detection_valid;
    reg [3:0] character;
    reg [34:0] bits;
    always @(*) begin
        pix_out=pix_in;dx=0;dy=0;column=0;row=0;bits=0;character=0;
        detection_valid=0;
        for(b=0;b<8;b=b+1) begin
            if (box_class[b][31] && supported_class(box_class[b][7:0]) && box_xy2[b][15:0]>=VIEW_X1 &&
                box_xy1[b][15:0]<=VIEW_X2) detection_valid=1;
            if(pix_de && in_video && box_class[b][31] && supported_class(box_class[b][7:0]) &&
               x>=box_xy1[b][15:0] && x<=box_xy2[b][15:0] &&
               source_y>=box_xy1[b][31:16] && source_y<=box_xy2[b][31:16]) begin
                if(x<box_xy1[b][15:0]+OSD_BORDER ||
                   x+OSD_BORDER>box_xy2[b][15:0] ||
                   source_y<box_xy1[b][31:16]+OSD_BORDER ||
                   source_y+OSD_BORDER>box_xy2[b][31:16])
                    pix_out=class_color(box_class[b][7:0]);
            end
        end
        // The optional debug guide never represents a recognition result.
        // A committed YOLO result takes precedence while it remains valid.
        if(GUIDE_ENABLE != 0 && pix_de && !detection_valid &&
           x>=GUIDE_X1 && x<=GUIDE_X2 &&
           y>=GUIDE_Y1 && y<=GUIDE_Y2 &&
           (x<GUIDE_X1+OSD_BORDER || x+OSD_BORDER>GUIDE_X2 ||
            y<GUIDE_Y1+OSD_BORDER || y+OSD_BORDER>GUIDE_Y2)) begin
            pix_out=GUIDE_COLOR;
        end
        // Render the highest-score result (slot 0) as text. Timing must be
        // checked on the complete top.
        if (OSD_TEXT != 0 && FOUR_BIN_CLASSES == 0) begin
            if(pix_de && box_class[0][31] &&
               x>=box_xy1[0][15:0] && x<=box_xy2[0][15:0] &&
               y>=box_xy1[0][31:16] && y<=box_xy2[0][31:16]) begin
                dx=x-box_xy1[0][15:0]-(OSD_BORDER+1);
                dy=y-box_xy1[0][31:16]-(OSD_BORDER+1);
                if(box_xy2[0][15:0]>=box_xy1[0][15:0]+52 &&
                   box_xy2[0][31:16]>=box_xy1[0][31:16]+20 &&
                   dx>=0 && dx<48 && dy>=0 && dy<16 &&
                   x+OSD_BORDER<=box_xy2[0][15:0] &&
                   y+OSD_BORDER<=box_xy2[0][31:16]) begin
                    if(dy<7 || (dy>=8 && dy<15)) begin
                        if(dx>=42) character=7;
                        else if(dx>=36) character=6;
                        else if(dx>=30) character=5;
                        else if(dx>=24) character=4;
                        else if(dx>=18) character=3;
                        else if(dx>=12) character=2;
                        else if(dx>=6) character=1;
                        else character=0;
                        column=dx-character*6;
                        row=dy<7 ? dy : dy-8;
                        bits=glyph(dy<7 ?
                            letter(box_class[0][2:0],character) :
                            bin_letter(box_class[0][2:0],character));
                        if(column<5 && bits[34-row*5-column]) pix_out=16'hffff;
                    end
                end
            end
        end
    end
endmodule
