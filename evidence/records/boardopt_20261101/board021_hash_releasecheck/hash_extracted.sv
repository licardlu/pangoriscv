module extracted_hash(input [31:0] pc,input [11:0] history,output [11:0] lookup_hash,learn_hash);
wire [11:0] pc_slice=pc[14:3];
assign lookup_hash=({pc_slice[0],pc_slice[1],pc_slice[2],pc_slice[3],pc_slice[4],pc_slice[5],pc_slice[6],pc_slice[7],pc_slice[8],pc_slice[9],pc_slice[10],pc_slice[11]} ^ (history & 12'h3ff));
assign learn_hash=({pc_slice[0],pc_slice[1],pc_slice[2],pc_slice[3],pc_slice[4],pc_slice[5],pc_slice[6],pc_slice[7],pc_slice[8],pc_slice[9],pc_slice[10],pc_slice[11]} ^ (history & 12'h3ff));
endmodule
