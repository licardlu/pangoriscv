// Read RGB888 DDR pixels ahead of the HDMI raster. Queue entries carry a
// frame generation and word index, so an underrun cannot shift later pixels.
module media_scanout #(
    parameter integer WIDTH=1280,HEIGHT=720,FIFO_DEPTH=128,FIFO_AW=7,
    parameter [27:0] BASE0=28'h2800000,BASE1=28'h2900000
)(
    input wire core_clk,core_rst,publish,publish_bank,
    output reg front_bank,presented,has_frame,
    input wire pix_clk,pix_rst,enabled,vs,de,
    input wire [10:0] x,input wire [9:0] y,
    output reg [23:0] rgb,output reg underflow,
    output reg [27:0] araddr,output wire [3:0] arlen,output reg arvalid,input wire arready,
    input wire [255:0] rdata,input wire rvalid,rlast
);
    localparam BURST=16;
    assign arlen=4'd15;
    reg vs_old,frame_toggle;reg [7:0] frame_generation;
    always @(posedge pix_clk)begin
        if(pix_rst)begin vs_old<=0;frame_toggle<=0;frame_generation<=0;end
        else begin vs_old<=vs;if(vs&&!vs_old)begin frame_toggle<=!frame_toggle;frame_generation<=frame_generation+1'b1;end end
    end
    (* ASYNC_REG="TRUE" *)reg [1:0] frame_sync,enabled_sync;
    reg frame_seen,restart,current_bank;
    reg [7:0] wanted_frame,read_frame;
    reg publish_pending,pending_bank,read_pending,finished;
    reg [16:0] next_word,requested_word;
    wire new_frame=frame_sync[1]!=frame_seen;
    wire full,empty;
    wire [280:0] queued;
    wire [FIFO_AW:0] queued_words;
    wire [16:0] expected_word=(y*WIDTH+x)>>3;
    wire head_matches=!empty&&queued[280:273]==frame_generation&&queued[272:256]==expected_word;
    // X/Y may retain the previous visible pixel throughout vertical blank.
    // Discard by position only when that position belongs to an active pixel.
    wire too_late=queued[272:256]<expected_word ||
                  (queued[272:256]==expected_word && x[2:0]!=0);
    wire discard=!empty&&(!enabled||queued[280:273]!=frame_generation||(de&&too_late));
    wire pop=discard||(enabled&&de&&x[2:0]==0&&head_matches);
    wire push=rvalid&&read_pending&&!full;
    async_fifo #(.DW(281),.DEPTH(FIFO_DEPTH),.AW(FIFO_AW)) prefetch(
        .wclk(core_clk),.wrst_n(!core_rst),.we(push),
        .wdata({read_frame,requested_word,rdata}),.full(full),.wlevel(queued_words),
        .rclk(pix_clk),.rrst_n(!pix_rst),.re(pop),.rdata(queued),.empty(empty));
    always @(posedge core_clk)begin
        if(core_rst)begin
            frame_sync<=0;enabled_sync<=0;frame_seen<=0;restart<=0;wanted_frame<=0;
            read_frame<=0;current_bank<=0;publish_pending<=0;pending_bank<=0;
            front_bank<=0;presented<=0;has_frame<=0;read_pending<=0;finished<=1;
            next_word<=0;requested_word<=0;araddr<=0;arvalid<=0;
        end else begin
            frame_sync<={frame_sync[0],frame_toggle};enabled_sync<={enabled_sync[0],enabled};
            if(publish)begin publish_pending<=1;pending_bank<=publish_bank;end
            if(new_frame)begin
                frame_seen<=frame_sync[1];wanted_frame<=wanted_frame+1'b1;restart<=1;
                if(publish_pending)begin
                    front_bank<=pending_bank;has_frame<=1;presented<=!presented;publish_pending<=0;
                end
            end
            if(arvalid&&arready)begin arvalid<=0;read_pending<=1;end
            if(rvalid&&read_pending)begin
                requested_word<=requested_word+1'b1;
                if(rlast)read_pending<=0;
            end
            // Never withdraw an accepted or stalled native request on a page
            // change. Finish it with its old generation before restarting.
            if(restart&&!arvalid&&!read_pending)begin
                restart<=0;read_frame<=wanted_frame;current_bank<=front_bank;
                next_word<=0;finished<=0;
            end else if(!restart&&!new_frame&&!arvalid&&!read_pending&&!finished&&
                        enabled_sync[1]&&has_frame&&queued_words<=FIFO_DEPTH-BURST)begin
                araddr<=(current_bank?BASE1:BASE0)+{8'd0,next_word,3'd0};
                requested_word<=next_word;arvalid<=1;
                if(next_word==WIDTH*HEIGHT/8-BURST)finished<=1;
                else next_word<=next_word+BURST;
            end
        end
    end
    reg [255:0] held_word;
    reg group_good;
    (* ASYNC_REG="TRUE" *)reg [1:0] valid_frame_sync;
    reg [23:0] rgb_d1;
    always @(posedge pix_clk)begin
        if(pix_rst)begin held_word<=0;group_good<=0;rgb_d1<=0;rgb<=0;underflow<=0;valid_frame_sync<=0;end
        else begin
            valid_frame_sync<={valid_frame_sync[0],has_frame};
            rgb<=rgb_d1;rgb_d1<=0;
            if(de&&enabled&&valid_frame_sync[1])begin
                if(x[2:0]==0)begin
                    group_good<=head_matches;
                    if(head_matches)begin held_word<=queued[255:0];rgb_d1<=queued[23:0];end
                    else begin held_word<=0;underflow<=1;end
                end else if(group_good)rgb_d1<=held_word[x[2:0]*32+:24];
            end
        end
    end
endmodule
