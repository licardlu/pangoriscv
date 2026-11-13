`timescale 1ns/1ps
// Behavioral replacement for the existing 256-bit write / 32-bit read IP.
// Only the IP primitive is modeled; rd_buf, sync_vg, OSD and panel are real RTL.
module rd_fram_buf(
    input [255:0] wr_data,input [8:0] wr_addr,input wr_en,wr_clk,wr_rst,
    output reg [31:0] rd_data,input [11:0] rd_addr,input rd_clk,rd_rst);
    reg [31:0] mem[0:4095];
    integer lane;
    always @(posedge wr_clk) if(wr_en && !wr_rst)
        for(lane=0;lane<8;lane=lane+1) mem[wr_addr*8+lane]<=wr_data[lane*32+:32];
    always @(posedge rd_clk) if(rd_rst) rd_data<=0;else rd_data<=mem[rd_addr];
endmodule

module tb_status_viewport;
    reg pix_clk=0,cpu_clk=0,ddr_clk=0;
    always #7 pix_clk=~pix_clk;
    always #5 cpu_clk=~cpu_clk;
    always #3 ddr_clk=~ddr_clk;
    reg rstn=0,raster_rstn=0;
    wire hs,vs,full_de;
    wire [11:0] display_y;
    // Same timing, gating and two-cycle alignment as the portable top.
    sync_vg raster(.clk(pix_clk),.rstn(raster_rstn),.hs_out(hs),.vs_out(vs),
        .de_out(full_de),.de_re(),.x_act(),.y_act(display_y));
    wire video_read=full_de && display_y>=48;
    reg [1:0] dp=0,hp=0,vp=0;
    always @(posedge pix_clk) begin
        if(!rstn) begin dp<=0;hp<=0;vp<=0;end
        else begin dp<={dp[0],full_de};hp<={hp[0],hs};vp<={vp[0],vs};end
    end
    wire [15:0] video_pixel,osd;
    wire video_de,req;
    wire [27:0] address;
    wire [31:0] length;
    reg done=0,data_en=0;
    reg [255:0] data=0;
    rd_buf #(.ADDR_WIDTH(28),.H_NUM(1280),.V_NUM(720),.DISPLAY_V_NUM(672),
        .DQ_WIDTH(32),.LEN_WIDTH(32),.PIX_WIDTH(16),.LINE_ADDR_WIDTH(22),.FRAME_CNT_WIDTH(6)) reader(
        .ddr_clk(ddr_clk),.ddr_rstn(rstn),.vout_clk(pix_clk),.rd_fsync(vs),.rd_en(video_read),
        .vout_de(video_de),.vout_data(video_pixel),.init_done(rstn),
        .ddr_rreq(req),.ddr_raddr(address),.ddr_rd_len(length),.ddr_rrdy(1'b1),.ddr_rdone(done),
        .ddr_rdata(data),.ddr_rdata_en(data_en),.wr_frame_id(6'd1));
    reg wr=0;reg [7:0] wa=0;reg [31:0] wd=0;
    wire [31:0] rd;
    video_ai_frontend #(.FOUR_BIN_CLASSES(1),.OSD_TEXT(0),.VIEW_Y1(48),.VIEW_HEIGHT(672)) frontend(
        .cpu_clk(cpu_clk),.cpu_rstn(rstn),.wr_en(wr),.rd_en(1'b0),.wr_addr(wa),.rd_addr(8'd0),.wr_data(wd),.rd_data(rd),
        .cam_clk(cpu_clk),.cam_rstn(rstn),.cam_vs(1'b0),.cam_de(1'b0),.cam_pixel(16'd0),
        .pix_clk(pix_clk),.pix_rstn(rstn),.pix_vs(vp[1]),.pix_de(dp[1]),.pix_in(video_pixel),.pix_out(osd),
        .result_commit(),.result_valid(),.result_class_id(),.result_count());
    wire ho,vo,deo;wire [23:0] rgb;
    reg [127:0] snapshot=0;
    light_split_video display(.clk(pix_clk),.rst(!rstn),.hs_in(hp[1]),.vs_in(vp[1]),
        .de_in(dp[1]),.pixel_in(osd),.snapshot(snapshot),.hs_out(ho),.vs_out(vo),.de_out(deo),.rgb_out(rgb));
    reg [15:0] scene[0:921599];
    reg [31:0] bg[0:1919],st[0:4859];reg [23:0] pal[0:15];
    integer requests=0,frame_requests=0,frame_tag=-1,ddr_state=0,delay_left,beat,src_row,p;
    reg vs_old=0;
    // Variable first-beat latency and gaps exercise the existing circular RAM.
    always @(negedge ddr_clk) begin
        done=0;data_en=0;
        if(!rstn) begin ddr_state=0;requests=0;frame_requests=0;frame_tag=-1;vs_old=0;end
        else begin
            vs_old=vs;
            if(reader.wr_rst) begin
                if(ddr_state!=0) $fatal(1,"frame restart with pending DDR command");
                if(frame_tag>=0 && frame_requests!=672) $fatal(1,"incomplete DDR command frame %0d: %0d",frame_tag,frame_requests);
                frame_tag=frame_tag+1;frame_requests=0;
            end
            case(ddr_state)
                0:if(req) begin
                    if(length!=80 || address[27:22]!=0) $fatal(1,"wrong DDR length or completed frame selection");
                    src_row=address/640;
                    if(frame_requests>=672 || src_row!=(frame_requests*719)/671)
                        $fatal(1,"DDR source mismatch dest=%0d source=%0d",frame_requests,src_row);
                    requests=requests+1;frame_requests=frame_requests+1;
                    delay_left=3+requests%11;beat=0;ddr_state=1;
                end
                1:if(delay_left>0) delay_left=delay_left-1;else ddr_state=2;
                2:begin
                    for(p=0;p<16;p=p+1) data[p*16+:16]=scene[src_row*1280+beat*16+p]^(frame_tag&1);
                    data_en=1;
                    if(beat==79) ddr_state=3;
                    else begin beat=beat+1;if(beat%13==0) begin delay_left=2;ddr_state=1;end end
                end
                3:begin done=1;ddr_state=0;end
            endcase
        end
    end
    function automatic [23:0] expand(input [15:0] c);
        expand={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};
    endfunction
    integer out_x=0,out_y=0,frames=0,pixels=0,sy,idx,preview,view_state;
    reg [23:0] expected;
    reg [15:0] expected565;
    reg [3:0] nibble;
    reg [1:0] check_de=0,check_hs=0,check_vs=0;
    reg de_previous=0;
    always @(posedge pix_clk) begin
        check_de<={check_de[0],dp[1]};check_hs<={check_hs[0],hp[1]};check_vs<={check_vs[0],vp[1]};
    end
    always @(negedge pix_clk) if(rstn) begin
        if(deo!==check_de[1] || ho!==check_hs[1] || vo!==check_vs[1]) $fatal(1,"compositor sync latency");
        if(video_read && display_y<48) $fatal(1,"camera read underneath status");
        if(video_de!==(dp[1] && frontend.y>=48)) $fatal(1,"DDR DE does not match dedicated viewport");
        if(dp[1] && frontend.y>=48 && frontend.source_y!==((frontend.y-48)*719)/671)
            $fatal(1,"OSD source coordinate mismatch at screen row %0d",frontend.y);
        if(deo) begin
            if(out_y<48) begin
                view_state=frames==0?0:1;
                if(out_x>=232&&out_x<788&&out_y>=12&&out_y<36) begin
                    idx=view_state*4320+((out_y-12)/2)*360+(out_x-232)/2;
                    nibble=(st[idx/8]>>((idx%8)*4))&15;
                end else begin
                    idx=(out_y/2)*640+out_x/2;nibble=(bg[idx/8]>>((idx%8)*4))&15;
                end
                expected=pal[nibble];
            end else begin
                sy=((out_y-48)*719)/671;
                expected565=scene[sy*1280+out_x]^(frames&1);
                // One injected blue detection; no material-name text.
                if(out_x>=450&&out_x<=809&&sy>=70&&sy<=639&&
                    (out_x<454||out_x+4>809||sy<74||sy+4>639)) expected565=16'h001f;
                expected=expand(expected565);
            end
            if(rgb!==expected) $fatal(1,"pixel mismatch frame=%0d xy=%0d,%0d source_y=%0d got=%h expected=%h",frames,out_x,out_y,sy,rgb,expected);
            if(frames==1) $fwrite(preview,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
            pixels=pixels+1;out_x=out_x+1;
        end else if(rgb!==0) $fatal(1,"nonblack blanking");
        if(de_previous&&!deo) begin
            if(out_x!=1280) $fatal(1,"wrong active line width %0d",out_x);
            out_x=0;out_y=out_y+1;
            if(out_y==720) begin
                if(frame_requests!=672) $fatal(1,"wrong request count %0d",frame_requests);
                frames=frames+1;out_y=0;snapshot[2:0]=1;
                if(frames==2) begin
                    $fclose(preview);
                    $display("TEST_PASS status_viewport two complete frames %0d pixels, 1344 DDR rows, source0..719, full FOV, OSD alignment, variable DDR latency, status isolation, RGB/sync",pixels);
                    $finish;
                end
            end
        end
        de_previous=deo;
    end
    task write(input [7:0] a,input [31:0] d);
        begin @(negedge cpu_clk);wr=1;wa=a;wd=d;@(negedge cpu_clk);wr=0;end
    endtask
    initial begin
        $readmemh("native_camera.hex",scene);$readmemh("ui_light_bg.hex",bg);
        $readmemh("ui_light_status.hex",st);$readmemh("ui_light_palette.hex",pal);
        preview=$fopen("frame.ppm","wb");$fwrite(preview,"P6\n1280 720\n255\n");
        repeat(5) @(negedge cpu_clk);rstn=1;
        write(8'h88,{16'd70,16'd450});write(8'h8c,{16'd639,16'd809});
        write(8'h90,32'h80000001);write(8'h94,1);
        repeat(10) @(negedge cpu_clk);raster_rstn=1;
    end
    initial begin #40000000;$fatal(1,"viewport timeout");end
endmodule
