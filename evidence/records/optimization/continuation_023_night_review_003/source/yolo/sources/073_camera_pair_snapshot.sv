// Equal frame-memory capacity to camera_snapshot: two N*8 banks replace N*16.
// mode=0: bank0/1 are the low/high bytes of the left RGB565 frame.
// mode=1: bank0/1 are left/right grayscale frames, acquired independently.
// Timestamps are common CPU-clock FRAME START counts, never exposure times.
`timescale 1ns/1ps
module camera_pair_snapshot #(
    parameter integer IN_W=1280, IN_H=720, STEP=4,
    parameter integer OUT_W=IN_W/STEP, OUT_H=IN_H/STEP,
    parameter integer TIMEOUT_CYCLES=27000000
)(
    input wire cpu_clk,cpu_rstn,request,pair_mode,
    input wire [15:0] read_address,
    output reg [15:0] read_data,
    output reg busy,ready,error,captured_pair,
    output reg [15:0] frame_id,right_frame_id,
    output reg [31:0] left_frame_tick,right_frame_tick,
    input wire left_clk,left_rstn,left_vs,left_de,
    input wire [15:0] left_pixel,
    input wire right_clk,right_rstn,right_vs,right_de,
    input wire [15:0] right_pixel
);
    localparam integer N=OUT_W*OUT_H;
    localparam integer TW=$clog2(TIMEOUT_CYCLES+1);
    localparam [2:0] IDLE=0, MODE_WAIT=1, CAPTURE_WAIT=2, QUARANTINE=3;
    reg [2:0] state;
    reg mode,request_toggle;
    reg [TW-1:0] timer;
    reg [31:0] ticks;
    // Register Gray at the source: a combinational binary->Gray expression
    // can glitch while binary carry bits settle, defeating the CDC coding.
    reg [31:0] gray_ticks;
    wire [31:0] next_ticks=ticks+1'b1;
    wire [15:0] left_index,right_index;
    wire left_we,right_we,left_done,right_done,left_bad,right_bad;
    wire [15:0] left_id,right_id;
    wire [31:0] left_tick,right_tick;
    wire left_mode,right_mode;
    (* ASYNC_REG="TRUE" *)reg [1:0] lm_sync,rm_sync,ld_sync,rd_sync;
    reg left_seen,right_seen;
    wire lcomplete=ld_sync[1]!=left_seen;
    wire rcomplete=rd_sync[1]!=right_seen;

    camera_pair_capture_lane #(.IN_W(IN_W),.IN_H(IN_H),.STEP(STEP),.N(N)) left_lane(
        .clk(left_clk),.rstn(left_rstn),.request_toggle(request_toggle),
        .mode_async(mode),.right_only(1'b0),.mode_ack(left_mode),
        .ticks_gray(gray_ticks),.vs(left_vs),.de(left_de),
        .write_enable(left_we),.write_address(left_index),.done_toggle(left_done),
        .frame_id(left_id),.frame_tick(left_tick),.error(left_bad));
    camera_pair_capture_lane #(.IN_W(IN_W),.IN_H(IN_H),.STEP(STEP),.N(N)) right_lane(
        .clk(right_clk),.rstn(right_rstn),.request_toggle(request_toggle),
        .mode_async(mode),.right_only(1'b1),.mode_ack(right_mode),
        .ticks_gray(gray_ticks),.vs(right_vs),.de(right_de),
        .write_enable(right_we),.write_address(right_index),.done_toggle(right_done),
        .frame_id(right_id),.frame_tick(right_tick),.error(right_bad));

    function automatic [7:0] gray565(input [15:0] pixel);
        reg [7:0] r,g,b;
        reg [9:0] sum;
        begin
            r={pixel[15:11],pixel[15:13]};
            g={pixel[10:5],pixel[10:9]};
            b={pixel[4:0],pixel[4:2]};
            sum={2'b0,r}+{1'b0,g,1'b0}+{2'b0,b};
            gray565=sum[9:2];
        end
    endfunction
    reg [7:0] bank0[0:N-1],bank1[0:N-1];
    wire bank1_clk;
    // Dedicated glitch-free clock mux. All lane writes are inactive during
    // mode handshake; launch occurs only after both domains acknowledge mode.
    GTP_CLKBUFGMUX #(.TRIGGER_MODE("NEGEDGE"),.SIM_DEVICE("LOGOS2"))
        bank1_clock(.CLKIN0(left_clk),.CLKIN1(right_clk),
                              .SEL(mode),.CLKOUT(bank1_clk));
    always @(posedge left_clk)
        if(left_we) bank0[left_index]<=left_mode?gray565(left_pixel):left_pixel[7:0];
    always @(posedge bank1_clk) begin
        if(mode) begin
            if(right_we)bank1[right_index]<=gray565(right_pixel);
        end else if(left_we)bank1[left_index]<=left_pixel[15:8];
    end
    always @(posedge cpu_clk) begin
        if(ready && read_address<N)read_data<={bank1[read_address],bank0[read_address]};
        else read_data<=0;
        if(!cpu_rstn) begin
            state<=IDLE;mode<=0;request_toggle<=0;timer<=0;ticks<=0;gray_ticks<=0;
            lm_sync<=0;rm_sync<=0;ld_sync<=0;rd_sync<=0;
            left_seen<=0;right_seen<=0;busy<=0;ready<=0;error<=0;
            captured_pair<=0;frame_id<=0;right_frame_id<=0;
            left_frame_tick<=0;right_frame_tick<=0;
        end else begin
            ticks<=next_ticks;gray_ticks<=(next_ticks>>1)^next_ticks;
            lm_sync<={lm_sync[0],left_mode};rm_sync<={rm_sync[0],right_mode};
            ld_sync<={ld_sync[0],left_done};rd_sync<={rd_sync[0],right_done};
            if(state==IDLE) begin
                if(request) begin
                    mode<=pair_mode;captured_pair<=pair_mode;
                    busy<=1;ready<=0;error<=0;timer<=0;
                    state<=MODE_WAIT;
                end
            end else if(state!=QUARANTINE) begin
                timer<=timer+1'b1;
                if(timer==TIMEOUT_CYCLES-1) begin
                    // A stopped camera may finish much later. Do not accept a
                    // new request or publish partial/stale RAM. Reset recovers.
                    error<=1;ready<=0;state<=QUARANTINE;
                end else if(state==MODE_WAIT && lm_sync[1]==mode &&
                            rm_sync[1]==mode) begin
                    left_seen<=ld_sync[1];right_seen<=rd_sync[1];
                    request_toggle<=!request_toggle;state<=CAPTURE_WAIT;
                end else if(state==CAPTURE_WAIT && lcomplete && (!mode || rcomplete)) begin
                    frame_id<=left_id;left_frame_tick<=left_tick;
                    right_frame_id<=mode?right_id:0;right_frame_tick<=mode?right_tick:0;
                    busy<=0;error<=left_bad || (mode && right_bad);
                    ready<=!left_bad && !(mode && right_bad);state<=IDLE;
                end
            end
        end
    end
endmodule

// One immutable capture controller per sensor. No frame memory here.
module camera_pair_capture_lane #(
    parameter integer IN_W=1280,IN_H=720,STEP=4,N=(IN_W/STEP)*(IN_H/STEP)
)(
    input wire clk,rstn,request_toggle,mode_async,right_only,
    output wire mode_ack,
    input wire [31:0] ticks_gray,
    input wire vs,de,
    output wire write_enable,
    output wire [15:0] write_address,
    output reg done_toggle,error,
    output reg [15:0] frame_id,
    output reg [31:0] frame_tick
);
    localparam integer XW=$clog2(IN_W+2),YW=$clog2(IN_H+2);
    (* ASYNC_REG="TRUE" *)reg [1:0] req_sync,mode_sync;
    reg settled_mode;
    reg [3:0] settle_count;
    (* ASYNC_REG="TRUE" *)reg [31:0] tick_sync0,tick_sync1;
    reg seen,pending,active,vs_d,de_d,malformed;
    reg [XW-1:0] x;
    reg [YW-1:0] y;
    reg [15:0] index,counter;
    wire frame_start=vs_d && !vs;
    assign mode_ack=settled_mode;
    assign write_address=index;
    assign write_enable=active && !frame_start && de && x<IN_W && y<IN_H &&
                        x%STEP==0 && y%STEP==0 && index<N;
    function automatic [31:0] binary_tick(input [31:0] gray);
        integer k;
        begin
            binary_tick[31]=gray[31];
            for(k=30;k>=0;k=k-1)binary_tick[k]=binary_tick[k+1]^gray[k];
        end
    endfunction
    always @(posedge clk) begin
        if(!rstn) begin
            req_sync<=0;mode_sync<=0;tick_sync0<=0;tick_sync1<=0;
            settled_mode<=0;settle_count<=0;
            seen<=0;pending<=0;active<=0;vs_d<=0;de_d<=0;malformed<=0;
            x<=0;y<=0;index<=0;counter<=0;done_toggle<=0;error<=0;
            frame_id<=0;frame_tick<=0;
        end else begin
            req_sync<={req_sync[0],request_toggle};mode_sync<={mode_sync[0],mode_async};
            if(mode_sync[1]==settled_mode)settle_count<=0;
            else if(settle_count==8)begin settled_mode<=mode_sync[1];settle_count<=0;end
            else settle_count<=settle_count+1'b1;
            tick_sync0<=ticks_gray;tick_sync1<=tick_sync0;
            vs_d<=vs;de_d<=de;
            if(req_sync[1]!=seen) begin
                seen<=req_sync[1];
                if(!right_only || mode_sync[1])pending<=1;
            end
            if(frame_start) begin
                counter<=counter+1'b1;x<=0;y<=0;
                if(active) begin
                    active<=0;error<=malformed || index!=N || y!=IN_H;
                    done_toggle<=!done_toggle;
                end else if(pending) begin
                    pending<=0;active<=1;index<=0;malformed<=0;error<=0;
                    frame_id<=counter;frame_tick<=binary_tick(tick_sync1);
                end
            end else if(active) begin
                if(de) begin
                    if(x<IN_W+1)x<=x+1'b1;
                    else malformed<=1;
                    if(write_enable)index<=index+1'b1;
                end
                if(de_d && !de) begin
                    if(x!=IN_W)malformed<=1;
                    x<=0;
                    if(y<IN_H+1)y<=y+1'b1;
                    else malformed<=1;
                end
            end
        end
    end
endmodule
