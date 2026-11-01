module t_io;
  integer f, rc;
  reg [63:0] v;
  reg [8*32-1:0] s;
  initial begin
    f = $fopen("probe_out.txt", "w");
    if (f != 0) begin $fdisplay(f, "abc123"); $fclose(f); $display("wrote ok"); end
    f = $fopen("probe_out.txt", "r");
    if (f != 0) begin rc = $fscanf(f, "%s", s); $display("rel rc=%0d s=%0s", rc, s); $fclose(f); end
    f = $fopen("E:/file/pango/project/ai_lab/gen/expected_k1.hex", "r");
    if (f != 0) begin rc = $fscanf(f, "%x", v); $display("abs rc=%0d v=%016x", rc, v); $fclose(f); end
    f = $fopen("E://file//pango//project//ai_lab//gen//expected_k1.hex", "r");
    if (f != 0) begin rc = $fscanf(f, "%x", v); $display("bs  rc=%0d v=%016x", rc, v); $fclose(f); end
    $finish;
  end
endmodule
