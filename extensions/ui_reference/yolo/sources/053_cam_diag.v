`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// cam_diag -- camera data path diagnostic overlay (v2)
//
// DDR3 is completely out of the loop. The raw camera stream is subsampled into a
// 160 x 90 on-chip array and blown back up 8x8 inside the 1280x720 window.
//
// A photo of the screen is enough to answer two questions:
//   row 0 (wy 0..7)   : white bar whose LENGTH = measured DE width / 2.
//                       1280 px full window -> bar reaches the right edge (1280)
//                        640 px             -> bar reaches half way
//   row 1 (wy 8..15)  : white bar whose LENGTH = lines counted between two vsyncs, /2
//                       750 lines -> 375 px, 525 lines -> 262 px
//   far right of both rows: cam1_ok / cam2_ok markers
//
// The subsample stride adapts to the measured line width, so the thumbnail fills
// the whole window whatever resolution the sensor is really running at.
//////////////////////////////////////////////////////////////////////////////////
module cam_diag(
    input               cam_clk,
    input               cam_rstn,
    input               cam_vs,
    input               cam_de,
    input      [15:0]   cam_d,

    input               disp_clk,
    input               disp_rstn,
    input      [11:0]   wx,
    input      [11:0]   wy,
    input      [3:0]    act1,
    input      [3:0]    act2,
    input      [1:0]    init_done,

    input      [13:0]   raddr2,     // second async read port, used by the UART dump
    output     [15:0]   rdata2,

    output     [12:0]   dbg_width,
    output     [12:0]   dbg_lines,

    output      [15:0]  px
);
    localparam [15:0] WHT = 16'hFFFF;
    localparam [15:0] GRY = 16'h2104;   // dark bar track
    localparam [15:0] GRN = 16'h07E0;
    localparam [15:0] RED = 16'hF800;

    reg  [12:0] cx;         // pclk counter inside one line
    reg  [11:0] cy;         // line counter
    reg         de_d;
    reg  [12:0] width_m;
    reg  [12:0] lines_m;
    reg  [12:0] width_q;
    reg  [12:0] lines_q;

    reg  [15:0] tmem [0:14399];
    reg         we;
    reg  [13:0] taddr;
    reg  [15:0] tdata;
    reg  [13:0] colm;

    // ---- subsample: one sample every 16 pclk, 160 columns fixed -----------
    always @(*)
    begin
        colm = {1'b0, cx[12:4]};        // 0..159 for a 2560-pclk line
    end

    wire stride_hit = (cx[3:0] == 4'd0);

    always @(posedge cam_clk)
        de_d <= cam_de;

    reg vs_d;
    always @(posedge cam_clk)
        vs_d <= cam_vs;
    wire vs_fall = vs_d && !cam_vs;      // end of the vertical sync pulse = frame boundary

    always @(posedge cam_clk)
    begin
        if (!cam_rstn) begin
            cx      <= 13'd0;
            cy      <= 12'd0;
            width_m <= 13'd0;
            lines_m <= 13'd0;
            we      <= 1'b0;
            taddr   <= 14'd0;
            tdata   <= 16'd0;
        end
        else if (vs_fall) begin
            cx      <= 13'd0;
            cy      <= 12'd0;
            lines_m <= {1'b0, cy};
            we      <= 1'b0;
        end
        else if (cam_de) begin
            cx    <= cx + 13'd1;
            we    <= stride_hit && (cy[2:0] == 3'd0);
            taddr <= ({2'b00, cy[10:3]} * 14'd160) + colm;
            tdata <= cam_d;
        end
        else begin
            cx <= 13'd0;
            we <= 1'b0;
            if (de_d) begin
                width_m <= cx;              // raw pclk cycles of DE, 2560 for 1280 px
                if (!(&cy)) cy <= cy + 12'd1;
            end
        end
    end

    always @(posedge cam_clk)
        if (we) tmem[taddr] <= tdata;

    // slow level shifters into the display clock domain
    reg [12:0] ws1, ws2, ls1, ls2;
    always @(posedge disp_clk)
    begin
        ws1 <= width_m;  ws2 <= ws1;  width_q <= ws2;
        ls1 <= lines_m;  ls2 <= ls1;  lines_q <= ls2;
    end

    reg  [13:0] raddr;
    reg  [15:0] tpx;
    reg  [15:0] px_c;

    always @(*)
    begin
        raddr = ({2'b00, wy[10:3]} * 14'd160) + {5'b0, wx[10:3]};
        tpx   = tmem[raddr];
    end

    assign rdata2 = tmem[raddr2];

    wire [11:0] wbar   = width_q[11:1];
    wire [11:0] lbar   = lines_q[11:1];
    wire [11:0] wbar_c = (wbar > 12'd1280) ? 12'd1280 : wbar;
    wire [11:0] lbar_c = (lbar > 12'd1280) ? 12'd1280 : lbar;

    always @(*)
    begin
        px_c = tpx;
        if (wy <= 12'd7) begin
            if      (wx >= 12'd1216) px_c = act1[3] ? GRN : RED;
            else if (wx >= 12'd1152) px_c = {16{init_done[0]}};
            else if (wx <  wbar_c)   px_c = WHT;
            else                     px_c = GRY;
        end
        else if (wy <= 12'd15) begin
            if      (wx >= 12'd1216) px_c = act2[3] ? GRN : RED;
            else if (wx >= 12'd1152) px_c = {16{init_done[1]}};
            else if (wx <  lbar_c)   px_c = WHT;
            else                     px_c = GRY;
        end
        else if (wy < 12'd16) begin
            px_c = tpx;
        end
    end

    assign px = disp_rstn ? px_c : 16'd0;

    assign dbg_width = width_q;
    assign dbg_lines = lines_q;

endmodule
