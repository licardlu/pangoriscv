module extracted_write(input clk,enable,init_busy,input [11:0] address,input [1:0] bank,input [7:0] data,output [7:0] value);
reg [7:0] memory [0:4095];assign value=memory[address];
  always @(posedge clk) begin
    if(enable) begin
      // Preserve counters for other halfword positions instead of restoring
      // their older fetch snapshots when one branch learns an outcome.
      if(init_busy || bank == 2'd0)
        memory[address][1:0] <= data[1:0];
      if(init_busy || bank == 2'd1)
        memory[address][3:2] <= data[3:2];
      if(init_busy || bank == 2'd2)
        memory[address][5:4] <= data[5:4];
      if(init_busy || bank == 2'd3)
        memory[address][7:6] <= data[7:6];
    end
  end

endmodule
