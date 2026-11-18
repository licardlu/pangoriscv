// 1280x720: independent status strip above a full-width video viewport.
// The upstream DDR reader samples the full source height into the video rows;
// no camera pixels are read beneath the dedicated status region.
// HS/VS/DE, selection and both RGB paths have two clocks of latency.
module light_split_video #(
    parameter integer HEADER_HEIGHT = 48,
    parameter integer BENCHMARK_ENABLE = 0,
    parameter BG = "ui_light_bg.hex",
    parameter PAL = "ui_light_palette.hex",
    parameter STATUS = "ui_light_status.hex"
) (
    input logic clk,rst,hs_in,vs_in,de_in,
    input logic [15:0] pixel_in,
    input logic [127:0] snapshot,
    input wire benchmark_active,
    input wire [23:0] benchmark_rgb,
    output wire [10:0] pixel_x,
    output wire [9:0] pixel_y,
    output logic hs_out,vs_out,de_out,
    output logic [23:0] rgb_out
);
    logic [15:0] pixel_d1,pixel_d2;
    logic select_d1,select_d2;
    logic [1:0] hp,vp,dp;
    logic de_prev;
    logic [10:0] x;
    logic [9:0] y;
    wire [23:0] panel_rgb;
    ui_light_panel #(.BG(BG),.PAL(PAL),.STATUS(STATUS)) light_panel(
        .clk(clk),.rst(rst),.x(x),.y(y),.snapshot(snapshot),.rgb(panel_rgb));
    function automatic [23:0] expand565(input logic [15:0] p);
        expand565={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};
    endfunction
    always_ff @(posedge clk)begin
        if(rst)begin
            x<=0;y<=0;de_prev<=0;hp<=0;vp<=0;dp<=0;
            pixel_d1<=0;pixel_d2<=0;select_d1<=0;select_d2<=0;
        end else begin
            hp<={hp[0],hs_in};vp<={vp[0],vs_in};dp<={dp[0],de_in};
            de_prev<=de_in;
            pixel_d1<=pixel_in;pixel_d2<=pixel_d1;
            select_d1<=de_in&&y>=HEADER_HEIGHT;
            select_d2<=select_d1;
            if(vs_in)begin x<=0;y<=0;end
            else if(de_in)x<=x+1'b1;
            else if(de_prev)begin x<=0;y<=y+1'b1;end
        end
    end
    assign hs_out=hp[1];assign vs_out=vp[1];assign de_out=dp[1];
    assign pixel_x=x;assign pixel_y=y;
    assign rgb_out=dp[1]?((BENCHMARK_ENABLE&&benchmark_active)?benchmark_rgb:
                    (select_d2?expand565(pixel_d2):panel_rgb)):24'h000000;
endmodule
