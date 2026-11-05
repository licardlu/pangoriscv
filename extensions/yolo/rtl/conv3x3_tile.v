// Minimal representative compute step for YOLO-Fastest 1.1 first conv layer:
// INT8 3x3 conv, 3 input channels, 8 output channels, 2x2 output tile (stride 2), pad 1,
// BN folded into weights/bias by the Python golden generator, requant M>>S, LeakyReLU(0.1).
module conv3x3_tile(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  done,
    output reg  out_valid,
    output reg  [5:0] out_idx,
    output reg  signed [7:0] out_data
);
    localparam S_REQ = 15;
    localparam [1:0] IDLE=2'd0, MAC=2'd1, OUT=2'd2, FIN=2'd3;
    reg [1:0] state;
    reg [1:0] pix;
    reg [1:0] cc, ky, kx;
    reg [2:0] ocnt;
    reg signed [31:0] acc [0:7];
    reg signed [7:0]  wmem [0:215];
    reg signed [7:0]  imem [0:74];
    reg signed [31:0] bmem [0:7];
    reg signed [31:0] mmem [0:7];
    initial begin
        $readmemh("w.hex",  wmem);
        $readmemh("in.hex", imem);
        $readmemh("b.hex",  bmem);
        $readmemh("m.hex",  mmem);
    end
    wire [3:0] prow = {2'b0, pix[1]} * 2 + {2'b0, ky};
    wire [3:0] pcol = {2'b0, pix[0]} * 2 + {2'b0, kx};
    wire [8:0] in_idx = (prow * 5 + pcol) * 3 + {7'b0, cc};
    wire [4:0] tap = {3'b0, cc} * 9 + {3'b0, ky} * 3 + {3'b0, kx};
    wire signed [7:0] ival = imem[in_idx];
    reg  signed [31:0] sum;
    reg  signed [63:0] a64, b64, prod, shifted, leaky;
    reg  signed [7:0]  clamp8;
    integer ch;
    always @(posedge clk) if (!rst_n) begin
        state<=IDLE; done<=1'b0; out_valid<=1'b0; out_idx<=6'd0; out_data<=8'sd0;
        pix<=2'd0; cc<=2'd0; ky<=2'd0; kx<=2'd0; ocnt<=3'd0;
        for (ch=0; ch<8; ch=ch+1) acc[ch] <= 32'sd0;
    end else begin
        case (state)
        IDLE: begin
            done<=1'b0; out_valid<=1'b0;
            if (start) begin
                pix<=2'd0; cc<=2'd0; ky<=2'd0; kx<=2'd0; ocnt<=3'd0;
                for (ch=0; ch<8; ch=ch+1) acc[ch] <= 32'sd0;
                state<=MAC;
            end
        end
        MAC: begin
            out_valid<=1'b0;
            for (ch=0; ch<8; ch=ch+1) acc[ch] <= acc[ch] + $signed(ival) * $signed(wmem[ch*27 + tap]);
            if (cc==2'd2 && ky==2'd2 && kx==2'd2) begin state<=OUT; ocnt<=3'd0; end
            else if (kx!=2'd2) kx<=kx+2'd1;
            else begin kx<=2'd0; if (ky!=2'd2) ky<=ky+2'd1; else begin ky<=2'd0; cc<=cc+2'd1; end end
        end
        OUT: begin
            sum  = acc[ocnt] + bmem[ocnt];
            a64  = {{32{sum[31]}}, sum};
            b64  = {{32{mmem[ocnt][31]}}, mmem[ocnt]};
            prod = a64 * b64;
            shifted = (prod + 64'sd16384) >>> S_REQ;
            if (shifted < 0) leaky = (shifted * 64'sd3277) >>> 15;
            else leaky = shifted;
            if (leaky > 64'sd127) clamp8 = 8'sd127;
            else if (leaky < -64'sd128) clamp8 = -8'sd128;
            else clamp8 = leaky[7:0];
            out_valid<=1'b1; out_data<=clamp8; out_idx<=pix*8 + ocnt;
            if (ocnt==3'd7) begin
                if (pix==2'd3) begin state<=FIN; end
                else begin
                    pix<=pix+2'd1; cc<=2'd0; ky<=2'd0; kx<=2'd0; ocnt<=3'd0;
                    for (ch=0; ch<8; ch=ch+1) acc[ch] <= 32'sd0;
                    state<=MAC;
                end
            end else ocnt<=ocnt+3'd1;
        end
        FIN: begin out_valid<=1'b0; done<=1'b1; state<=IDLE; end
        default: state<=IDLE;
        endcase
    end
endmodule
