// CPU indirect command at 9c, staging/result at b8. a0..b4 retain the
// accelerator's existing bulk-memory protocol. Bank 0 is read-only MMC;
// bank 1 controls sector streaming; bank 2 reports decoder/display status.
module media_subsystem #(
    parameter integer WIDTH=1280,HEIGHT=720
)(
    input wire cpu_clk,cpu_rst,wr_en,input wire [7:0] wr_addr,rd_addr,
    input wire [31:0] wr_data,output reg [31:0] rd_data,
    input wire [1:0] page,input wire card_detect_n,
    input tri0 audio_clk,audio_rst,audio_page,audio_ready,
    output wire audio_valid,output wire [31:0] audio_pcm,
    output wire sd_clk,inout wire sd_cmd,inout wire [3:0] sd_dat,
    input wire core_clk,core_rst,pix_clk,pix_rst,page_active,vs,de,
    input wire [10:0] x,input wire [9:0] y,output wire [23:0] rgb,
    output reg [3:0] ui_state,output wire [7:0] decoder_status,
    output wire [27:0] awaddr,output wire awvalid,input wire awready,
    output wire [255:0] wdata,output wire [31:0] wstrb,input wire wready,wlast,
    output wire [27:0] araddr,output wire [3:0] arlen,output wire arvalid,input wire arready,
    input wire [255:0] rdata,input wire rvalid,rlast
);
    reg [31:0] staging,result,command_data,expected_crc;
    reg [11:0] command_address;
    reg command_pending,command_write,command_error,bus_issued;
    reg start_pending,frame_start,sector_start,frame_end,stream_abort;
    reg frame_in_progress,decoder_low_seen,publish_toggle,publish_wait,expected_ack;
    reg [8:0] slice_skip;reg [9:0] slice_length;
    reg [3:0] reset_count;
    wire resetting=reset_count!=0;
    wire reset_active_core;
    (* ASYNC_REG="TRUE" *) reg [1:0] detect_sync,reset_ack_sync;
    (* ASYNC_REG="TRUE" *) reg [7:0] status_meta,status_sync;
    reg [31:0] pixels_meta,pixels_sync;
    wire [31:0] decoded_pixels;
    wire busy=command_pending||start_pending||resetting||reset_ack_sync[1];
    wire stream_busy,stream_done,stream_error,finalized;
    wire [31:0] stream_crc;
    wire out_valid,out_ready,out_last;wire [31:0] out_data;
    wire token_ready;
    wire token_valid=start_pending||out_valid;
    wire [33:0] token_data=start_pending?{2'd2,32'd0}:{1'b0,out_last,out_data};
    assign out_ready=token_ready&&!start_pending;
    wire fifo_read_req,fifo_read_ready,fifo_read_valid,fifo_read_error;
    wire [31:0] fifo_read_data;
    wire audio_req,audio_read_ready,audio_read_valid,audio_busy;
    wire [11:0] audio_level;
    wire [31:0] audio_result;
    wire audio_write_ok=(command_address==12'h300&&command_data<=2)||
        (command_address==12'h304&&command_data[1:0]==0&&command_data[17:16]==0&&
         command_data[25:16]!=0&&{1'b0,command_data[8:0]}+command_data[25:16]<=512)||
        (command_address==12'h308&&(command_data==1||command_data==2)&&
         !stream_busy&&!audio_busy&&(command_data==2||audio_level<=1920));
    wire audio_wr=command_pending&&command_write&&command_address[11:8]==3&&audio_write_ok;
    wire video_req,video_ready,video_valid;
    reg audio_read_owner;
    assign fifo_read_req=audio_req||video_req;
    assign audio_read_ready=fifo_read_ready;
    assign video_ready=fifo_read_ready&&!audio_req;
    assign audio_read_valid=fifo_read_valid&&audio_read_owner;
    assign video_valid=fifo_read_valid&&!audio_read_owner;
    always @(posedge cpu_clk)begin
        if(cpu_rst)audio_read_owner<=0;
        else if(fifo_read_req&&fifo_read_ready)audio_read_owner<=audio_req;
    end
    media_audio pcm_audio(.cpu_clk(cpu_clk),.cpu_rst(cpu_rst),.wr(audio_wr),
        .address(command_address[7:0]),.data(command_data),.result(audio_result),
        .busy_o(audio_busy),.buffer_level(audio_level),
        .audio_clk(audio_clk),.audio_rst(audio_rst),.page_active(audio_page),
        .sample_ready(audio_ready),.sample_valid(audio_valid),.sample_pcm(audio_pcm),
        .read_req(audio_req),.read_ready(audio_read_ready),.read_valid(audio_read_valid),
        .read_error(fifo_read_error),.read_data(fifo_read_data));
    media_sector_stream stream(.clk(cpu_clk),.rst(cpu_rst),.frame_start(frame_start),
        .sector_start(sector_start),.sector_skip(slice_skip),.sector_length(slice_length),
        .frame_end(frame_end),.abort(stream_abort),.busy(stream_busy),.sector_done(stream_done),
        .error(stream_error),.finalized(finalized),.crc32(stream_crc),
        .read_req(video_req),.read_ready(video_ready),.read_valid(video_valid),
        .read_data(fifo_read_data),.read_error(fifo_read_error),
        .out_valid(out_valid),.out_ready(out_ready),.out_data(out_data),.out_last(out_last));
    media_decode_pipeline #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) pipeline(
        .cpu_clk(cpu_clk),.cpu_rst(cpu_rst),.soft_reset(resetting),.token_valid(token_valid),
        .token_data(token_data),.token_ready(token_ready),.publish_toggle(publish_toggle),
        .core_clk(core_clk),.core_rst(core_rst),.status(decoder_status),.pixels(decoded_pixels),
        .reset_active(reset_active_core),.pix_clk(pix_clk),.pix_rst(pix_rst),.page_active(page_active),
        .vs(vs),.de(de),.x(x),.y(y),.rgb(rgb),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),
        .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
        .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rlast(rlast));
    wire host_ready,host_done,host_error;wire [31:0] host_result;
    wire cfg_awvalid,cfg_awready,cfg_wvalid,cfg_wready,cfg_bvalid,cfg_bready;
    wire cfg_arvalid,cfg_arready,cfg_rvalid,cfg_rready;
    wire [31:0] cfg_awaddr,cfg_wdata,cfg_araddr,cfg_rdata;wire [1:0] cfg_bresp,cfg_rresp;
    wire host_valid=command_pending&&command_address[11:8]==0&&!bus_issued;
    media_mmc_bus bus(.clk(cpu_clk),.rst(cpu_rst),.host_valid(host_valid),.host_ready(host_ready),
        .host_write(command_write),.host_address(command_address[7:0]),.host_data(command_data),
        .host_done(host_done),.host_error(host_error),.host_result(host_result),
        .stream_req(fifo_read_req),.stream_ready(fifo_read_ready),.stream_valid(fifo_read_valid),
        .stream_data(fifo_read_data),.stream_error(fifo_read_error),
        .awvalid(cfg_awvalid),.awaddr(cfg_awaddr),.awready(cfg_awready),
        .wvalid(cfg_wvalid),.wdata(cfg_wdata),.wready(cfg_wready),
        .bvalid(cfg_bvalid),.bresp(cfg_bresp),.bready(cfg_bready),
        .arvalid(cfg_arvalid),.araddr(cfg_araddr),.arready(cfg_arready),
        .rvalid(cfg_rvalid),.rdata(cfg_rdata),.rresp(cfg_rresp),.rready(cfg_rready));
    wire cmd_out,cmd_oe;
    assign sd_cmd=cmd_oe?cmd_out:1'bz;
    // DAT pins remain inputs at the FPGA boundary, independently of software.
    assign sd_dat=4'bzzzz;
    mmc_card card(.clk_i(cpu_clk),.rst_i(cpu_rst),
        .cfg_awvalid_i(cfg_awvalid),.cfg_awaddr_i(cfg_awaddr),.cfg_awready_o(cfg_awready),
        .cfg_wvalid_i(cfg_wvalid),.cfg_wdata_i(cfg_wdata),.cfg_wstrb_i(4'hf),.cfg_wready_o(cfg_wready),
        .cfg_bvalid_o(cfg_bvalid),.cfg_bresp_o(cfg_bresp),.cfg_bready_i(cfg_bready),
        .cfg_arvalid_i(cfg_arvalid),.cfg_araddr_i(cfg_araddr),.cfg_arready_o(cfg_arready),
        .cfg_rvalid_o(cfg_rvalid),.cfg_rdata_o(cfg_rdata),.cfg_rresp_o(cfg_rresp),.cfg_rready_i(cfg_rready),
        .mmc_clk_o(sd_clk),.mmc_cmd_out_o(cmd_out),.mmc_cmd_out_en_o(cmd_oe),
        .mmc_cmd_in_i(sd_cmd),.mmc_dat_in_i(sd_dat),
        .outport_awready_i(1'b0),.outport_wready_i(1'b0),.outport_bvalid_i(1'b0),
        .outport_bresp_i(2'd0),.outport_bid_i(4'd0),.outport_arready_i(1'b0),
        .outport_rvalid_i(1'b0),.outport_rdata_i(32'd0),.outport_rresp_i(2'd0),
        .outport_rid_i(4'd0),.outport_rlast_i(1'b0));
    always @(*)begin
        rd_data=0;
        if(rd_addr==8'h9c)rd_data={busy,command_error,!detect_sync[1],resetting,publish_wait,
                                  9'd0,page,16'h5344};
        if(rd_addr==8'hb8)rd_data=result;
    end
    always @(posedge cpu_clk)begin
        if(cpu_rst)begin
            staging<=0;result<=0;command_data<=0;command_address<=0;
            command_pending<=0;command_write<=0;command_error<=0;bus_issued<=0;
            start_pending<=0;frame_start<=0;sector_start<=0;frame_end<=0;stream_abort<=0;
            frame_in_progress<=0;decoder_low_seen<=0;publish_toggle<=0;publish_wait<=0;expected_ack<=0;
            slice_skip<=0;slice_length<=0;expected_crc<=0;ui_state<=0;reset_count<=0;
            detect_sync<=3;reset_ack_sync<=3;status_meta<=0;status_sync<=0;pixels_meta<=0;pixels_sync<=0;
        end else begin
            detect_sync<={detect_sync[0],card_detect_n};reset_ack_sync<={reset_ack_sync[0],reset_active_core};
            status_meta<=decoder_status;status_sync<=status_meta;pixels_meta<=decoded_pixels;pixels_sync<=pixels_meta;
            frame_start<=0;sector_start<=0;frame_end<=0;stream_abort<=0;
            if(reset_count!=0)reset_count<=reset_count-1'b1;
            if(start_pending&&token_ready)begin start_pending<=0;frame_start<=1;end
            if(frame_in_progress&&!status_sync[1])decoder_low_seen<=1;
            if(publish_wait&&status_sync[4]!=expected_ack)publish_wait<=0;
            if(host_valid&&host_ready)bus_issued<=1;
            if(host_done&&bus_issued)begin
                command_pending<=0;bus_issued<=0;command_error<=host_error;result<=host_result;
            end
            if(command_pending&&command_address[11:8]!=0)begin
                command_pending<=0;command_error<=0;result<=0;
                if(command_write)begin
                    case(command_address)
                        12'h100:case(command_data)
                            1:if(stream_busy||frame_in_progress||publish_wait||status_sync[2]||resetting||reset_ack_sync[1])command_error<=1;
                              else begin start_pending<=1;frame_in_progress<=1;decoder_low_seen<=0;end
                            2:if(stream_busy||audio_busy||!frame_in_progress||!slice_length||{1'b0,slice_skip}+slice_length>512)command_error<=1;
                              else sector_start<=1;
                            4:if(stream_busy||!frame_in_progress)command_error<=1;else frame_end<=1;
                            8:begin stream_abort<=1;reset_count<=12;start_pending<=0;frame_in_progress<=0;decoder_low_seen<=0;end
                            default:command_error<=1;
                        endcase
                        12'h104:begin slice_skip<=command_data[8:0];slice_length<=command_data[25:16];end
                        12'h108:expected_crc<=command_data;
                        12'h10c:ui_state<=command_data[3:0];
                        12'h200:if(command_data!=1||!finalized||stream_error||stream_crc!=expected_crc||
                                   !decoder_low_seen||!status_sync[1]||status_sync[0]||publish_wait)command_error<=1;
                                else begin publish_toggle<=!publish_toggle;publish_wait<=1;expected_ack<=status_sync[4];frame_in_progress<=0;end
                        default:if(command_address[11:8]==3)command_error<=!audio_write_ok;else command_error<=1;
                    endcase
                end else begin
                    case(command_address)
                        12'h104:result<={6'd0,slice_length,7'd0,slice_skip};
                        12'h108:result<=expected_crc;
                        12'h10c:result<={28'd0,ui_state};
                        12'h110:result<=stream_crc;
                        12'h114:result<={29'd0,stream_error,finalized,stream_busy};
                        12'h200:result<={24'd0,status_sync[7:2],status_sync[1]&&decoder_low_seen,status_sync[0]};
                        12'h204:result<=pixels_sync;
                        12'h208:result<={31'd0,publish_wait};
                        default:if(command_address[11:8]==3&&command_address[7:0]<=8'h1c&&command_address[1:0]==0)result<=audio_result;else command_error<=1;
                    endcase
                end
            end
            if(wr_en&&wr_addr==8'hb8)staging<=wr_data;
            if(wr_en&&wr_addr==8'h9c)begin
                if(busy)command_error<=1;
                else begin
                    command_address<=wr_data[11:0];command_write<=wr_data[31];command_data<=staging;
                    command_pending<=1;bus_issued<=0;command_error<=0;
                end
            end
        end
    end
    wire unused_stream_done=stream_done;
endmodule
