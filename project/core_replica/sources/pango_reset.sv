// Assert on loss of lock or KEY0. Release only after four CPU rising edges.
module pango_reset(input wire clk, input wire rst_n, input wire locked,
                   output wire reset);
  (* ASYNC_REG = "TRUE" *) reg [3:0] release_pipe = 4'b0000;
  wire ready = rst_n & locked;
  always @(posedge clk or negedge ready)
    if (!ready) release_pipe <= 4'b0000;
    else release_pipe <= {release_pipe[2:0], 1'b1};
  assign reset = !ready || !release_pipe[3];
endmodule
