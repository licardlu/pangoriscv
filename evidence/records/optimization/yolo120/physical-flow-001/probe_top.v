module probe(input wire clk, output wire q); reg [7:0] count=0; always @(posedge clk) count<=count+1; assign q=count[7]; endmodule
