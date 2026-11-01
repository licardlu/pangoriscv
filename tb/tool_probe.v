// Isolates PDS tool launch from the CPU design. Not part of the SoC.
module tool_probe(input wire a, output wire y);
  assign y = a;
endmodule
