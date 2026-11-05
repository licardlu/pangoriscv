// Camera snapshot + frame-boundary OSD mailbox. The 8-box payload remains
// stable across CDC until the pixel domain acknowledges it.
`timescale 1ns/1ps
module video_ai_frontend #(
    // Retained for register/instantiation compatibility; OSD visibility is
    // controlled by detection_valid and the fixed guide, never by expiry.
    parameter integer RESULT_TTL=120,
    // Keep text enabled for the reusable frontend and unit-test contract.
    // Board-level generators may explicitly disable it on timing-sensitive
    // pixel paths.
    parameter integer OSD_TEXT=1,
    parameter integer OSD_BORDER=4,
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
    output reg [15:0] pix_out
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
    reg request_toggle,ack_toggle;
    reg [1:0] ack_sync,request_sync;
    wire osd_busy=request_toggle!=ack_sync[1];
    integer i;
    always @(posedge cpu_clk) begin
        if(!cpu_rstn) begin
            snapshot_address<=0;selected<=0;request_toggle<=0;ack_sync<=0;
            for(i=0;i<8;i=i+1) begin
                stage_xy1[i]<=0;stage_xy2[i]<=0;stage_class[i]<=0;
                payload_xy1[i]<=0;payload_xy2[i]<=0;payload_class[i]<=0;
            end
        end else begin
            ack_sync<={ack_sync[0],ack_toggle};
            if(wr_en) case(wr_addr)
                8'h78:snapshot_address<=wr_data[15:0];
                8'h84:selected<=wr_data[2:0];
                8'h88:stage_xy1[selected]<=wr_data;
                8'h8c:stage_xy2[selected]<=wr_data;
                8'h90:stage_class[selected]<=wr_data;
                8'h94:if(wr_data[0] && !osd_busy) begin
                    request_toggle<=!request_toggle;
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
    integer j;
    always @(posedge pix_clk) begin
        if(!pix_rstn) begin
            request_sync<=0;ack_toggle<=0;x<=0;y<=0;vs_d<=0;de_d<=0;age<=RESULT_TTL;
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
                    for(j=0;j<8;j=j+1) begin
                        box_xy1[j]<=payload_xy1[j];box_xy2[j]<=payload_xy2[j];
                        box_class[j]<=payload_class[j];
                    end
                    ack_toggle<=request_sync[1];age<=0;
                end else if(age<RESULT_TTL) age<=age+1'b1;
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
            if (box_class[b][31] && box_xy2[b][15:0]>=VIEW_X1 &&
                box_xy1[b][15:0]<=VIEW_X2) detection_valid=1;
            if(pix_de && box_class[b][31] &&
               x>=box_xy1[b][15:0] && x<=box_xy2[b][15:0] &&
               y>=box_xy1[b][31:16] && y<=box_xy2[b][31:16]) begin
                if(x<box_xy1[b][15:0]+OSD_BORDER ||
                   x+OSD_BORDER>box_xy2[b][15:0] ||
                   y<box_xy1[b][31:16]+OSD_BORDER ||
                   y+OSD_BORDER>box_xy2[b][31:16])
                    pix_out=class_color(box_class[b][2:0]);
            end
        end
        // Keep a stable capture guide on screen whenever the detector has no
        // valid result. A committed YOLO result takes precedence for the
        // entire frame; an empty result restores the guide on the next frame.
        if(pix_de && !detection_valid &&
           x>=GUIDE_X1 && x<=GUIDE_X2 &&
           y>=GUIDE_Y1 && y<=GUIDE_Y2 &&
           (x<GUIDE_X1+OSD_BORDER || x+OSD_BORDER>GUIDE_X2 ||
            y<GUIDE_Y1+OSD_BORDER || y+OSD_BORDER>GUIDE_Y2)) begin
            pix_out=GUIDE_COLOR;
        end
        // Render the highest-score result (slot 0) as text. Timing must be
        // checked on the complete top.
        if (OSD_TEXT != 0) begin
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
