module media_decode_pipeline #(
    parameter integer WIDTH=1280,HEIGHT=720
)(
    input wire cpu_clk,cpu_rst,soft_reset,token_valid,
    input wire [33:0] token_data,output wire token_ready,
    input wire publish_toggle,
    input wire core_clk,core_rst,output wire [7:0] status,output wire [31:0] pixels,
    output wire reset_active,
    input wire pix_clk,pix_rst,page_active,vs,de,
    input wire [10:0] x,input wire [9:0] y,output wire [23:0] rgb,
    output wire [27:0] awaddr,output wire awvalid,input wire awready,
    output wire [255:0] wdata,output wire [31:0] wstrb,input wire wready,wlast,
    output wire [27:0] araddr,output wire [3:0] arlen,output wire arvalid,input wire arready,
    input wire [255:0] rdata,input wire rvalid,rlast
);
    (* ASYNC_REG="TRUE" *)reg [1:0] reset_sync,publish_sync,underflow_sync;
    reg publish_seen,protocol_error;
    wire reset_decoder=core_rst||reset_sync[1];
    assign reset_active=reset_decoder;
    wire fifo_full,fifo_empty;
    wire [33:0] head;
    wire token_start=head[33:32]==2;
    wire jpeg_accept,jpeg_idle,pixel_valid,pixel_ready,writer_done,writer_error,writer_busy;
    wire [15:0] width,height,px,py;wire [7:0] red,green,blue;
    wire front_bank,presented,has_frame,underflow;
    wire consume=!fifo_empty&&!reset_decoder&&(token_start?!writer_busy:jpeg_accept);
    wire start_frame=consume&&token_start;
    wire compressed_valid=!fifo_empty&&!token_start&&!reset_decoder;
    assign token_ready=!fifo_full&&!soft_reset&&!cpu_rst;
    async_fifo #(.DW(34),.DEPTH(16),.AW(4)) input_fifo(
        .wclk(cpu_clk),.wrst_n(!cpu_rst&&!soft_reset),.we(token_valid&&token_ready),
        .wdata(token_data),.full(fifo_full),.rclk(core_clk),.rrst_n(!reset_decoder),
        .re(consume),.rdata(head),.empty(fifo_empty));
    jpeg_core decoder(.clk_i(core_clk),.rst_i(reset_decoder),
        .inport_valid_i(compressed_valid),.inport_data_i(head[31:0]),.inport_strb_i(4'hf),
        .inport_last_i(compressed_valid&&head[33:32]==1),.inport_accept_o(jpeg_accept),
        .outport_accept_i(pixel_ready),.outport_valid_o(pixel_valid),
        .outport_width_o(width),.outport_height_o(height),.outport_pixel_x_o(px),
        .outport_pixel_y_o(py),.outport_pixel_r_o(red),.outport_pixel_g_o(green),
        .outport_pixel_b_o(blue),.idle_o(jpeg_idle));
    reg written_bank;
    media_jpeg_writer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) writer(
        .clk(core_clk),.rst(core_rst),.frame_start(start_frame),.abort(reset_sync[1]),
        .back_buffer(!front_bank),.pixel_valid(pixel_valid),.pixel_ready(pixel_ready),
        .pixel_x(px),.pixel_y(py),.image_width(width),.image_height(height),.pixel_rgb({red,green,blue}),
        .frame_done(writer_done),.error(writer_error),.busy(writer_busy),.pixels(pixels),
        .awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),
        .wready(wready),.wlast(wlast));
    wire publish_event=publish_sync[1]!=publish_seen;
    wire publish_frame=publish_event&&writer_done&&!writer_error&&!reset_decoder;
    media_scanout #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) display(
        .core_clk(core_clk),.core_rst(core_rst),.publish(publish_frame),.publish_bank(written_bank),
        .front_bank(front_bank),.presented(presented),.has_frame(has_frame),
        .pix_clk(pix_clk),.pix_rst(pix_rst),.enabled(page_active),.vs(vs),.de(de),.x(x),.y(y),
        .rgb(rgb),.underflow(underflow),.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
        .rdata(rdata),.rvalid(rvalid),.rlast(rlast));
    always @(posedge core_clk)begin
        if(core_rst)begin
            reset_sync<=0;publish_sync<=0;underflow_sync<=0;publish_seen<=0;protocol_error<=0;written_bank<=0;
        end else begin
            reset_sync<={reset_sync[0],soft_reset};publish_sync<={publish_sync[0],publish_toggle};
            underflow_sync<={underflow_sync[0],underflow};
            if(start_frame)begin written_bank<=!front_bank;protocol_error<=0;end
            if(publish_event)begin
                publish_seen<=publish_sync[1];
                if(!writer_done||writer_error)protocol_error<=1;
            end
            if(reset_sync[1])protocol_error<=0;
        end
    end
    assign status={jpeg_idle,underflow_sync[1],has_frame,presented,front_bank,
                   writer_busy,writer_done,writer_error||protocol_error};
endmodule
