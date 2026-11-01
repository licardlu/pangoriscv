module t_read;
  reg [63:0] m [0:15];
  integer i, fd, rc;
  reg [8*64-1:0] sbuf;
  initial begin
    for (i=0;i<16;i=i+1) m[i]=64'hdead_beef_dead_beef;
    $readmemh("ddr_k1.hex", m);
    $display("readmemh: m0=%016x m1=%016x m2=%016x", m[0], m[1], m[2]);
    for (i=0;i<16;i=i+1) m[i]=64'hdead_beef_dead_beef;
    fd = $fopen("ddr_k1.hex","r");
    $display("fopen=%0d", fd);
    rc = $fgets(sbuf, fd);
    $display("fgets rc=%0d sbuf=%0s", rc, sbuf);
    rc = $sscanf(sbuf, "%x", m[0]);
    $display("sscanf rc=%0d m0=%016x", rc, m[0]);
    rc = $fscanf(fd, "%x", m[1]);
    $display("fscanf rc=%0d m1=%016x", rc, m[1]);
    $finish;
  end
endmodule
