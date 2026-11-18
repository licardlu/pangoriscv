// Three independent native DDR clients: existing video, AI, and media.
// A granted owner remains selected until its final WLAST/RLAST beat.
module ddr_native_arbiter3(
 input wire clk,rstn,input wire [83:0] s_awaddr,s_araddr,input wire [11:0] s_awlen,s_arlen,
 input wire [11:0] s_awid,s_arid,input wire [2:0] s_awvalid,s_arvalid,
 output wire [2:0] s_awready,s_arready,input wire [767:0] s_wdata,input wire [95:0] s_wstrb,
 output wire [2:0] s_wready,s_wlast,output wire [255:0] s_rdata,output wire [2:0] s_rvalid,s_rlast,
 output wire [3:0] s_rid,output wire [27:0] m_awaddr,m_araddr,output wire [3:0] m_awlen,m_arlen,m_awid,m_arid,
 output wire m_awvalid,m_arvalid,input wire m_awready,m_arready,output wire [255:0] m_wdata,
 output wire [31:0] m_wstrb,input wire m_wready,m_wlast,input wire [255:0] m_rdata,input wire m_rvalid,m_rlast,input wire [3:0] m_rid);
 reg wb,rb,ws,rs;reg [1:0] wo,ro,wp,rp;
 function automatic [1:0] choose(input [2:0] valid,input [1:0] preferred);
  reg [1:0] second,third;
  begin second=preferred==2?0:preferred+1;third=second==2?0:second+1;
   choose=valid[preferred]?preferred:valid[second]?second:third;end
 endfunction
 assign m_awaddr=s_awaddr[wo*28 +:28];assign m_awlen=s_awlen[wo*4 +:4];assign m_awid=s_awid[wo*4 +:4];
 assign m_awvalid=wb&&!ws&&s_awvalid[wo];assign s_awready=wb&&!ws?({2'b0,m_awready}<<wo):0;
 assign m_wdata=s_wdata[wo*256 +:256];assign m_wstrb=s_wstrb[wo*32 +:32];assign s_wready=wb?({2'b0,m_wready}<<wo):0;assign s_wlast=wb?({2'b0,m_wlast}<<wo):0;
 assign m_araddr=s_araddr[ro*28 +:28];assign m_arlen=s_arlen[ro*4 +:4];assign m_arid=s_arid[ro*4 +:4];
 assign m_arvalid=rb&&!rs&&s_arvalid[ro];assign s_arready=rb&&!rs?({2'b0,m_arready}<<ro):0;
 assign s_rdata=m_rdata;assign s_rid=m_rid;assign s_rvalid=rb?({2'b0,m_rvalid}<<ro):0;assign s_rlast=rb?({2'b0,m_rlast}<<ro):0;
 always @(posedge clk)begin
  if(!rstn)begin wb<=0;rb<=0;ws<=0;rs<=0;wo<=0;ro<=0;wp<=0;rp<=0;end else begin
   if(!wb&&|s_awvalid)begin wo<=choose(s_awvalid,wp);wb<=1;ws<=0;end
   if(m_awvalid&&m_awready)ws<=1;
   if(wb&&(ws||(m_awvalid&&m_awready))&&m_wlast)begin wb<=0;wp<=wo==2?0:wo+1;end
   if(!rb&&|s_arvalid)begin ro<=choose(s_arvalid,rp);rb<=1;rs<=0;end
   if(m_arvalid&&m_arready)rs<=1;
   if(rb&&(rs||(m_arvalid&&m_arready))&&m_rvalid&&m_rlast)begin rb<=0;rp<=ro==2?0:ro+1;end
  end
 end
endmodule
