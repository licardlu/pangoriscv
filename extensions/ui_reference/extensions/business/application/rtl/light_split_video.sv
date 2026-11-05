// Low-resource 1280x720 split display path.
//
// The input is the native RGB565 stream after YOLO OSD. The right 640 pixels
// show source x=320..959 through a 320-active-pixel line delay, preserving the
// source overlay pixels without a second box-coordinate transform. The left
// 640 pixels come from ui_light_panel, whose output is specified as two-cycle
// latency. HS/VS/DE and the source-select bit are delayed by two cycles to
// match both pixel paths. Blanking does not consume line-delay RAM entries.
module light_split_video #(
    parameter integer CROP_DELAY = 320,
    parameter integer RIGHT_X0 = 640,
    parameter BG = "ui_light_bg.hex",
    parameter PAL = "ui_light_palette.hex",
    parameter STATUS = "ui_light_status.hex"
) (
    input  logic         clk,
    input  logic         rst,
    input  logic         hs_in,
    input  logic         vs_in,
    input  logic         de_in,
    input  logic [15:0]  pixel_in,
    input  logic [127:0] snapshot,
    output logic         hs_out,
    output logic         vs_out,
    output logic         de_out,
    output logic [23:0]  rgb_out
);
    localparam integer PTR_W = (CROP_DELAY <= 1) ? 1 : $clog2(CROP_DELAY);

    // One line-delay ring. It is intentionally left uncleared: the right
    // output is selected only after CROP_DELAY active pixels have filled the
    // current line, so stale values can never reach a valid right pixel.
    logic [15:0] delay_mem [0:CROP_DELAY-1];
    logic [PTR_W-1:0] wr_ptr;
    logic [15:0] crop_d1, crop_d2;
    logic select_d1, select_d2;

    logic hs_d1, hs_d2, vs_d1, vs_d2, de_d1, de_d2;
    logic de_prev;
    logic [10:0] x;
    logic [9:0] y;
    logic [23:0] panel_rgb;

    // The parent integration provides the production renderer. The testbench
    // supplies a two-cycle stub with this exact contract.
    ui_light_panel #(.BG(BG), .PAL(PAL), .STATUS(STATUS)) light_panel (
        .clk(clk), .rst(rst), .x(x), .y(y), .snapshot(snapshot), .rgb(panel_rgb)
    );

    function automatic [23:0] expand565(input logic [15:0] p);
        expand565 = {p[15:11], p[15:13],
                     p[10:5], p[10:9],
                     p[4:0], p[4:2]};
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= '0;
            crop_d1  <= '0;
            crop_d2  <= '0;
            select_d1 <= 1'b0;
            select_d2 <= 1'b0;
            hs_d1 <= 1'b0; hs_d2 <= 1'b0;
            vs_d1 <= 1'b0; vs_d2 <= 1'b0;
            de_d1 <= 1'b0; de_d2 <= 1'b0;
            de_prev <= 1'b0;
            x <= '0;
            y <= '0;
        end else begin
            // Sync and DE are deliberately pipelined independently of the
            // pixel path so blanking remains phase matched.
            hs_d1 <= hs_in; hs_d2 <= hs_d1;
            vs_d1 <= vs_in; vs_d2 <= vs_d1;
            de_d1 <= de_in; de_d2 <= de_d1;
            de_prev <= de_in;

            if (vs_in) begin
                x <= '0;
                y <= '0;
                wr_ptr <= '0;
            end else if (de_in) begin
                crop_d1 <= delay_mem[wr_ptr];
                delay_mem[wr_ptr] <= pixel_in;
                select_d1 <= (x >= RIGHT_X0);
                if (wr_ptr == CROP_DELAY-1)
                    wr_ptr <= '0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
                x <= x + 1'b1;
            end else begin
                crop_d1 <= '0;
                select_d1 <= 1'b0;
                if (de_prev) begin
                    x <= '0;
                    y <= y + 1'b1;
                    wr_ptr <= '0;
                end
            end

            crop_d2 <= crop_d1;
            select_d2 <= select_d1;
        end
    end

    assign hs_out = hs_d2;
    assign vs_out = vs_d2;
    assign de_out = de_d2;
    assign rgb_out = de_d2
                   ? (select_d2 ? expand565(crop_d2) : panel_rgb)
                   : 24'h000000;
endmodule
