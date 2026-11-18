// Read-only SD PCM sectors -> block RAM async FIFO -> shared HDMI I2S.
// The media clock advances only for samples actually accepted by I2S.
module media_audio #(parameter integer DEPTH=2048,AW=11)(
 input wire cpu_clk,cpu_rst,wr,input wire [7:0] address,input wire [31:0] data,
 output reg [31:0] result,
 output wire busy_o,output wire [AW:0] buffer_level,
 input wire audio_clk,audio_rst,page_active,sample_ready,
 output wire sample_valid,output reg [31:0] sample_pcm,
 output wire read_req,input wire read_ready,read_valid,read_error,input wire [31:0] read_data
);
 reg enable;reg [5:0] clear_count;reg stream_start,sector_start;
 reg [8:0] skip;reg [9:0] length;
 wire clearing=clear_count!=0;
 wire busy,stream_error,pcm_valid,pcm_ready;wire [31:0] pcm_word;
 wire [31:0] unused_crc;wire unused_done,unused_final,unused_last;
 media_sector_stream stream(.clk(cpu_clk),.rst(cpu_rst),.abort(clearing),
  .frame_start(stream_start),.sector_start(sector_start),.sector_skip(skip),.sector_length(length),
  .frame_end(1'b0),.busy(busy),.error(stream_error),.sector_done(unused_done),
  .finalized(unused_final),.crc32(unused_crc),.read_req(read_req),.read_ready(read_ready),
  .read_valid(read_valid),.read_error(read_error),.read_data(read_data),
  .out_valid(pcm_valid),.out_ready(pcm_ready),.out_data(pcm_word),.out_last(unused_last));
 // 2048 stereo frames fit the two remaining DRM36K blocks. Registered read
 // removes the deep LUT RAM mux and its routing load from the full design.
 (* ram_style="block" *) reg [31:0] memory[0:DEPTH-1];
 reg [AW:0] wp,rp,wgray,rgray;
 (* ASYNC_REG="TRUE" *) reg [AW:0] rmeta,rsync,wmeta,wsync;
 (* ASYNC_REG="TRUE" *) reg [1:0] clear_sync,enable_sync;
 reg [31:0] samples,underflows,samples_gray,underflows_gray;
 (* ASYNC_REG="TRUE" *) reg [31:0] samples_meta,samples_sync,underflows_meta,underflows_sync;
 function automatic [AW:0] binary(input [AW:0] g);
  integer i;begin binary[AW]=g[AW];for(i=AW-1;i>=0;i--)binary[i]=binary[i+1]^g[i];end
 endfunction
 function automatic [31:0] binary32(input [31:0] g);
  integer i;begin binary32[31]=g[31];for(i=30;i>=0;i--)binary32[i]=binary32[i+1]^g[i];end
 endfunction
 wire full=wgray==(rsync^{2'b11,{(AW-1){1'b0}}});
 wire empty=rgray==wsync;
 wire [AW:0] level=wp-binary(rsync);
 assign busy_o=busy||clearing;
 assign buffer_level=level;
 assign pcm_ready=!full&&!clearing;
 assign sample_valid=!empty&&enable_sync[1]&&!clear_sync[1]&&page_active;
 // Prefetch the next word on a transfer; otherwise hold the current address.
 // Gray-pointer synchronization gives new writes time to reach this read port
 // before empty falls. No reset on the memory read register: infer native RAM.
 wire [AW-1:0] read_address=rp[AW-1:0]+(sample_valid&&sample_ready);
 always @(posedge audio_clk)sample_pcm<=memory[read_address];
 always @(*)begin
  result=0;
  case(address)
   8'h00:result={30'd0,clearing,enable};
   8'h04:result={6'd0,length,7'd0,skip};
   8'h08:result={30'd0,stream_error,busy||clearing};
   8'h0c:result={{(31-AW){1'b0}},level};
   8'h10:result=binary32(samples_sync);
   8'h14:result=binary32(underflows_sync);
   8'h18:result=DEPTH;
   8'h1c:result=unused_crc;
   default:;
  endcase
 end
 always @(posedge cpu_clk)begin
  if(cpu_rst)begin
   enable<=0;clear_count<=32;stream_start<=0;sector_start<=0;skip<=0;length<=0;
   wp<=0;wgray<=0;rmeta<=0;rsync<=0;
   samples_meta<=0;samples_sync<=0;underflows_meta<=0;underflows_sync<=0;
  end else begin
   stream_start<=0;sector_start<=0;
   samples_meta<=samples_gray;samples_sync<=samples_meta;
   underflows_meta<=underflows_gray;underflows_sync<=underflows_meta;
   if(clearing)begin
    clear_count<=clear_count-1'b1;wp<=0;wgray<=0;rmeta<=0;rsync<=0;
    // Open after the reset level has fallen; the stream sees this pulse next cycle.
    if(clear_count==1)stream_start<=1;
   end else begin
    rmeta<=rgray;rsync<=rmeta;
    if(pcm_valid&&pcm_ready)begin memory[wp[AW-1:0]]<=pcm_word;wp<=wp+1'b1;wgray<=((wp+1'b1)>>1)^(wp+1'b1);end
   end
   if(wr)case(address)
    8'h00:if(data[1])begin enable<=0;clear_count<=32;end else enable<=data[0];
    8'h04:begin skip<=data[8:0];length<=data[25:16];end
    8'h08:begin
     if(data==1&&!busy&&!clearing&&level<=DEPTH-128)sector_start<=1;
     if(data==2&&!busy&&!clearing)stream_start<=1;
    end
    default:;
   endcase
  end
 end
 always @(posedge audio_clk)begin
  if(audio_rst)begin
   clear_sync<=3;enable_sync<=0;wmeta<=0;wsync<=0;rp<=0;rgray<=0;
   samples<=0;samples_gray<=0;underflows<=0;underflows_gray<=0;
  end else begin
   clear_sync<={clear_sync[0],clearing};enable_sync<={enable_sync[0],enable};
   if(clear_sync[1])begin
    wmeta<=0;wsync<=0;rp<=0;rgray<=0;samples<=0;samples_gray<=0;underflows<=0;underflows_gray<=0;
   end else begin
    wmeta<=wgray;wsync<=wmeta;
    if(sample_ready&&page_active&&enable_sync[1])begin
     if(!empty)begin
      rp<=rp+1'b1;rgray<=((rp+1'b1)>>1)^(rp+1'b1);
      samples<=samples+1'b1;samples_gray<=((samples+1'b1)>>1)^(samples+1'b1);
     end else begin
      underflows<=underflows+1'b1;underflows_gray<=((underflows+1'b1)>>1)^(underflows+1'b1);
     end
    end
   end
  end
 end
endmodule
