module extracted_write(input clk,enable,init_busy,input [11:0] address,input [1:0] bank,input [7:0] data,output [7:0] value);
reg [7:0] memory [0:4095];assign value=memory[address];
  always @(posedge clk) begin
    if(enable) begin
      memory[address] <= data;
    end
  end

endmodule
