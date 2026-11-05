// Camera snapshot + frame-boundary OSD mailbox. The 8-box payload remains
// stable across CDC until the pixel domain acknowledges it.
`timescale 1ns/1ps
module video_ai_frontend #(
    // Number of display frames for which the last detection remains visible
    // after the first explicitly empty inference. Slow inference alone must
    // not erase a valid result. The board wrapper sets a frame-rate-specific
    // TTL: 60 frames at 30 Hz, or 120 frames at 60 Hz, gives two seconds.
    parameter integer RESULT_TTL=60,
    // Keep text enabled for the reusable frontend and unit-test contract.
    // Board-level generators may explicitly disable it on timing-sensitive
    // pixel paths.
    parameter integer OSD_TEXT=1,
    parameter integer OSD_BORDER=4,
    parameter integer HEADER_HEIGHT=0,
    parameter integer SCREEN_WIDTH=1280,
    parameter integer SCREEN_HEIGHT=720,
    parameter integer OSD_LABEL=1,
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
    parameter [15:0] GUIDE_COLOR=16'h07e0
) (
    input wire cpu_clk,cpu_rstn,
    input wire wr_en,
    input wire [7:0] wr_addr,rd_addr,
    input wire [31:0] wr_data,
    output reg [31:0] rd_data,
    input wire cam_clk,cam_rstn,cam_vs,cam_de,
    input wire [15:0] cam_pixel,
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
    camera_snapshot capture(
        .cpu_clk(cpu_clk),.cpu_rstn(cpu_rstn),
        .request(wr_en && wr_addr==8'h74 && wr_data[0]),
        .read_address(snapshot_address),.read_data(snapshot_data),
        .busy(cap_busy),.ready(cap_ready),.error(cap_error),.frame_id(frame_id),
        .cam_clk(cam_clk),.cam_rstn(cam_rstn),.vsync(cam_vs),.de(cam_de),.pixel(cam_pixel));
    reg [2:0] selected;
    reg [31:0] stage_xy1[0:7],stage_xy2[0:7],stage_class[0:7];
    reg [31:0] payload_xy1[0:7],payload_xy2[0:7],payload_class[0:7];
    wire payload_has_detection=payload_class[0][31] || payload_class[1][31] ||
        payload_class[2][31] || payload_class[3][31] || payload_class[4][31] ||
        payload_class[5][31] || payload_class[6][31] || payload_class[7][31];
    reg request_toggle,ack_toggle;
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
            for(i=0;i<8;i=i+1) begin
                stage_xy1[i]<=0;stage_xy2[i]<=0;stage_class[i]<=0;
                payload_xy1[i]<=0;payload_xy2[i]<=0;payload_class[i]<=0;
            end
        end else begin
            ack_sync<={ack_sync[0],ack_toggle};
            result_commit<=0;
            if(wr_en) case(wr_addr)
                8'h78:snapshot_address<=wr_data[15:0];
                8'h84:selected<=wr_data[2:0];
                8'h88:stage_xy1[selected]<=wr_data;
                8'h8c:stage_xy2[selected]<=wr_data;
                8'h90:stage_class[selected]<=wr_data;
                8'h94:if(wr_data[0] && !osd_busy) begin
                    request_toggle<=!request_toggle;
                    result_commit<=1;
                    result_valid<=stage_count!=0;
                    result_class_id<=stage_first_class;
                    result_count<=stage_count;
                    for(i=0;i<8;i=i+1) begin
                        payload_xy1[i]<=stage_xy1[i];
                        payload_xy2[i]<=stage_xy2[i];
                        payload_class[i]<=stage_class[i];
                    end
                end
                default:;
            endcase
        end
    end
    always @(*) begin
        case(rd_addr)
            8'h7c:rd_data={16'b0,snapshot_data};
            8'h80:rd_data={frame_id,13'b0,cap_error,cap_ready,cap_busy};
            8'h98:rd_data={31'b0,osd_busy};
            default:rd_data=0;
        endcase
    end
    reg [31:0] box_xy1[0:7],box_xy2[0:7],box_class[0:7];
    reg [15:0] x,y;
    reg vs_d,de_d;
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
                    if(payload_has_detection) begin
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
    function [15:0] class_color;
        input [2:0] category;
        begin
            case(category)
                0: class_color=16'hfd20;
                1: class_color=16'hffe0;
                2: class_color=16'h07ff;
                3: class_color=16'h001f;
                4: class_color=16'hf81f;
                5: class_color=16'h07e0;
                default: class_color=16'hffff;
            endcase
        end
    endfunction
    function [2:0] label_kind;
        input [2:0] class_id;
        begin
            if(class_id==3'd0) label_kind=3'd0; // kitchen
            else if(class_id<=3'd5) label_kind=3'd1; // recyclable
            else if(class_id==3'd6) label_kind=3'd2; // other
            else label_kind=3'd3; // hazardous
        end
    endfunction
    function [3:0] label_glyph;
        input [2:0] kind;
        input [2:0] index;
        begin
            case(kind)
                3'd0: case(index) 0:label_glyph=9; 1:label_glyph=10; 2:label_glyph=3; default:label_glyph=4; endcase
                3'd1: case(index) 0:label_glyph=0; 1:label_glyph=1; 2:label_glyph=2; 3:label_glyph=3; default:label_glyph=4; endcase
                3'd2: case(index) 0:label_glyph=5; 1:label_glyph=6; 2:label_glyph=3; default:label_glyph=4; endcase
                default: case(index) 0:label_glyph=7; 1:label_glyph=8; 2:label_glyph=3; default:label_glyph=4; endcase
            endcase
        end
    endfunction
    // 12x12 Microsoft YaHei glyph rows, doubled to a 24px display size.
    function [11:0] cjk_row;
        input [3:0] glyph_id;
        input [3:0] glyph_y;
        begin
            cjk_row=12'h000;
            case(glyph_id)
                4'd0: case(glyph_y)
                    4'd0:cjk_row=12'h7ff;
                    4'd1:cjk_row=12'h004;
                    4'd2:cjk_row=12'h004;
                    4'd3:cjk_row=12'h3e4;
                    4'd4:cjk_row=12'h224;
                    4'd5:cjk_row=12'h224;
                    4'd6:cjk_row=12'h224;
                    4'd7:cjk_row=12'h3e4;
                    4'd8:cjk_row=12'h204;
                    4'd9:cjk_row=12'h004;
                    4'd10:cjk_row=12'h03c;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd1: case(glyph_y)
                    4'd0:cjk_row=12'h7fe;
                    4'd1:cjk_row=12'h402;
                    4'd2:cjk_row=12'h402;
                    4'd3:cjk_row=12'h4fa;
                    4'd4:cjk_row=12'h48a;
                    4'd5:cjk_row=12'h48a;
                    4'd6:cjk_row=12'h4fa;
                    4'd7:cjk_row=12'h48a;
                    4'd8:cjk_row=12'h402;
                    4'd9:cjk_row=12'h7fe;
                    4'd10:cjk_row=12'h402;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd2: case(glyph_y)
                    4'd0:cjk_row=12'h120;
                    4'd1:cjk_row=12'h140;
                    4'd2:cjk_row=12'h57e;
                    4'd3:cjk_row=12'h5c4;
                    4'd4:cjk_row=12'h5c4;
                    4'd5:cjk_row=12'h544;
                    4'd6:cjk_row=12'h528;
                    4'd7:cjk_row=12'h728;
                    4'd8:cjk_row=12'h510;
                    4'd9:cjk_row=12'h16c;
                    4'd10:cjk_row=12'h1c3;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd3: case(glyph_y)
                    4'd0:cjk_row=12'h210;
                    4'd1:cjk_row=12'h208;
                    4'd2:cjk_row=12'h27f;
                    4'd3:cjk_row=12'hf00;
                    4'd4:cjk_row=12'h242;
                    4'd5:cjk_row=12'h246;
                    4'd6:cjk_row=12'h224;
                    4'd7:cjk_row=12'h224;
                    4'd8:cjk_row=12'h3a8;
                    4'd9:cjk_row=12'hc08;
                    4'd10:cjk_row=12'h0ff;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd4: case(glyph_y)
                    4'd0:cjk_row=12'h2fc;
                    4'd1:cjk_row=12'h244;
                    4'd2:cjk_row=12'hf48;
                    4'd3:cjk_row=12'h24e;
                    4'd4:cjk_row=12'h262;
                    4'd5:cjk_row=12'h262;
                    4'd6:cjk_row=12'h264;
                    4'd7:cjk_row=12'h394;
                    4'd8:cjk_row=12'hc88;
                    4'd9:cjk_row=12'h0b6;
                    4'd10:cjk_row=12'h163;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd5: case(glyph_y)
                    4'd0:cjk_row=12'h204;
                    4'd1:cjk_row=12'hfff;
                    4'd2:cjk_row=12'h204;
                    4'd3:cjk_row=12'h3fc;
                    4'd4:cjk_row=12'h204;
                    4'd5:cjk_row=12'h3fc;
                    4'd6:cjk_row=12'h204;
                    4'd7:cjk_row=12'hfff;
                    4'd8:cjk_row=12'h000;
                    4'd9:cjk_row=12'h39c;
                    4'd10:cjk_row=12'hc03;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd6: case(glyph_y)
                    4'd0:cjk_row=12'h110;
                    4'd1:cjk_row=12'h350;
                    4'd2:cjk_row=12'h27e;
                    4'd3:cjk_row=12'h6d2;
                    4'd4:cjk_row=12'he52;
                    4'd5:cjk_row=12'ha52;
                    4'd6:cjk_row=12'h25e;
                    4'd7:cjk_row=12'h250;
                    4'd8:cjk_row=12'h251;
                    4'd9:cjk_row=12'h241;
                    4'd10:cjk_row=12'h27e;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd7: case(glyph_y)
                    4'd0:cjk_row=12'h040;
                    4'd1:cjk_row=12'h040;
                    4'd2:cjk_row=12'h7ff;
                    4'd3:cjk_row=12'h080;
                    4'd4:cjk_row=12'h1fe;
                    4'd5:cjk_row=12'h102;
                    4'd6:cjk_row=12'h3fe;
                    4'd7:cjk_row=12'h502;
                    4'd8:cjk_row=12'h1fe;
                    4'd9:cjk_row=12'h102;
                    4'd10:cjk_row=12'h11e;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd8: case(glyph_y)
                    4'd0:cjk_row=12'h030;
                    4'd1:cjk_row=12'h7ff;
                    4'd2:cjk_row=12'h421;
                    4'd3:cjk_row=12'h3fe;
                    4'd4:cjk_row=12'h020;
                    4'd5:cjk_row=12'h3fe;
                    4'd6:cjk_row=12'h020;
                    4'd7:cjk_row=12'h7ff;
                    4'd8:cjk_row=12'h202;
                    4'd9:cjk_row=12'h3fe;
                    4'd10:cjk_row=12'h202;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd9: case(glyph_y)
                    4'd0:cjk_row=12'h7ff;
                    4'd1:cjk_row=12'h402;
                    4'd2:cjk_row=12'h5e2;
                    4'd3:cjk_row=12'h41f;
                    4'd4:cjk_row=12'h5e2;
                    4'd5:cjk_row=12'h532;
                    4'd6:cjk_row=12'h5ea;
                    4'd7:cjk_row=12'h40a;
                    4'd8:cjk_row=12'h542;
                    4'd9:cjk_row=12'h862;
                    4'd10:cjk_row=12'hb8c;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                4'd10: case(glyph_y)
                    4'd0:cjk_row=12'h040;
                    4'd1:cjk_row=12'h0a0;
                    4'd2:cjk_row=12'h318;
                    4'd3:cjk_row=12'h7fe;
                    4'd4:cjk_row=12'h840;
                    4'd5:cjk_row=12'h040;
                    4'd6:cjk_row=12'hffe;
                    4'd7:cjk_row=12'h150;
                    4'd8:cjk_row=12'h248;
                    4'd9:cjk_row=12'h444;
                    4'd10:cjk_row=12'h9c2;
                    4'd11:cjk_row=12'h000;
                    default:cjk_row=12'h000;
                endcase
                default:cjk_row=12'h000;
            endcase
        end
    endfunction
    integer b,draw_top,label_x,label_y,label_w,label_len,label_dx,label_dy,label_col,label_row,label_index;
    integer detection_valid;
    reg [2:0] category_kind;
    reg [3:0] glyph_id;
    reg [11:0] glyph_bits;
    localparam integer LABEL_SCALE=2;
    localparam integer LABEL_PAD=4;
    localparam integer LABEL_HEIGHT=32;
    always @(*) begin
        pix_out=pix_in;
        detection_valid=0;
        draw_top=0;label_x=0;label_y=0;label_w=0;label_len=0;
        label_dx=0;label_dy=0;label_col=0;label_row=0;label_index=0;
        category_kind=0;glyph_id=0;glyph_bits=0;
        for(b=0;b<8;b=b+1) begin
            draw_top=box_xy1[b][31:16];
            if(box_class[b][31] && box_xy2[b][15:0]>=VIEW_X1 &&
               box_xy1[b][15:0]<=VIEW_X2) detection_valid=1;
            // The opaque UI header owns rows [0, HEADER_HEIGHT). Clip a
            // detection's visible top edge to the live-video area below it.
            if(pix_de && box_class[b][31] &&
               x>=box_xy1[b][15:0] && x<=box_xy2[b][15:0] &&
               y>=box_xy1[b][31:16] && y<=box_xy2[b][31:16]) begin
                if(x<box_xy1[b][15:0]+OSD_BORDER ||
                   x+OSD_BORDER>box_xy2[b][15:0] ||
                   y<box_xy1[b][31:16]+OSD_BORDER || y+OSD_BORDER>box_xy2[b][31:16])
                    pix_out=class_color(box_class[b][2:0]);
            end
        end
        // The optional debug guide never represents a recognition result.
        if(GUIDE_ENABLE != 0 && pix_de && !detection_valid &&
           y>=HEADER_HEIGHT && x>=GUIDE_X1 && x<=GUIDE_X2 &&
           y>=GUIDE_Y1 && y<=GUIDE_Y2 &&
           (x<GUIDE_X1+OSD_BORDER || x+OSD_BORDER>GUIDE_X2 ||
            y<GUIDE_Y1+OSD_BORDER || y+OSD_BORDER>GUIDE_Y2)) begin
            pix_out=GUIDE_COLOR;
        end
        // Solid dark tag at the box's upper-left; glyphs are 24px high.
        // Near the top edge, place it immediately below the opaque header.
        if(OSD_LABEL != 0) begin
            for(b=0;b<8;b=b+1) begin
                if(box_class[b][31] && box_xy2[b][15:0]>=VIEW_X1 &&
                   box_xy1[b][15:0]<=VIEW_X2) begin
                    category_kind=label_kind(box_class[b][2:0]);
                    label_len=(category_kind==3'd1)?5:4;
                    label_w=label_len*24+LABEL_PAD*2;
                    label_x=box_xy1[b][15:0];
                    if(label_x+label_w>SCREEN_WIDTH) label_x=SCREEN_WIDTH-label_w;
                    draw_top=box_xy1[b][31:16];
                    if(draw_top>=LABEL_HEIGHT) label_y=draw_top-LABEL_HEIGHT;
                    else label_y=0;
                    if(label_y+LABEL_HEIGHT>SCREEN_HEIGHT)
                        label_y=SCREEN_HEIGHT-LABEL_HEIGHT;
                    if(pix_de && x>=label_x && x<label_x+label_w &&
                       y>=label_y && y<label_y+LABEL_HEIGHT) begin
                        pix_out=16'h1247;
                        label_dx=x-label_x-LABEL_PAD;
                        label_dy=y-label_y-LABEL_PAD;
                        if(label_dx>=0 && label_dx<label_len*24 &&
                           label_dy>=0 && label_dy<24) begin
                            label_index=label_dx/24;
                            label_col=(label_dx%24)/LABEL_SCALE;
                            label_row=label_dy/LABEL_SCALE;
                            glyph_id=label_glyph(category_kind,label_index[2:0]);
                            glyph_bits=cjk_row(glyph_id,label_row[3:0]);
                            if(glyph_bits[11-label_col]) pix_out=16'hffff;
                        end
                    end
                end
            end
        end
    end
endmodule
