// JPEG produces 8x8 blocks. Scatter each contiguous eight-pixel run into
// its DDR row, preserving all RGB888 bits in zero-padded 32-bit pixels.
module media_jpeg_writer #(
    parameter integer WIDTH=1280,HEIGHT=720,
    parameter [27:0] BASE0=28'h2800000,BASE1=28'h2900000
)(
    input wire clk,rst,frame_start,abort,back_buffer,
    input wire pixel_valid,output wire pixel_ready,
    input wire [15:0] pixel_x,pixel_y,image_width,image_height,
    input wire [23:0] pixel_rgb,
    output reg frame_done,error,output wire busy,output reg [31:0] pixels,
    output reg [27:0] awaddr,output reg awvalid,input wire awready,
    output wire [255:0] wdata,output wire [31:0] wstrb,
    input wire wready,wlast
);
    reg opened,write_active,address_sent,completion_seen,bank;
    reg [2:0] packed_pixels;
    reg [255:0] packed_data;
    reg [15:0] run_x,run_y;
    assign busy=opened||write_active;
    assign pixel_ready=opened&&!write_active&&!error;
    assign wdata=packed_data;
    assign wstrb=32'hffffffff;
    always @(posedge clk)begin
        if(rst)begin
            opened<=0;write_active<=0;address_sent<=0;completion_seen<=0;bank<=0;
            packed_pixels<=0;packed_data<=0;run_x<=0;run_y<=0;pixels<=0;
            awaddr<=0;awvalid<=0;frame_done<=0;error<=0;
        end else begin
            if(awvalid&&awready)begin awvalid<=0;address_sent<=1;end
            if(write_active)begin
                if(wlast)completion_seen<=1;
                if((address_sent||(awvalid&&awready))&&(completion_seen||wlast))begin
                    write_active<=0;address_sent<=0;completion_seen<=0;
                end
            end
            if(opened&&pixels==WIDTH*HEIGHT&&!write_active)begin opened<=0;frame_done<=!error;end
            if(frame_start)begin
                if(busy)error<=1;
                else begin
                    opened<=1;bank<=back_buffer;pixels<=0;packed_pixels<=0;packed_data<=0;
                    frame_done<=0;error<=0;
                end
            end
            if(pixel_valid&&pixel_ready)begin
                if(image_width!=WIDTH || image_height!=HEIGHT || pixel_x>=WIDTH || pixel_y>=HEIGHT ||
                   pixels>=WIDTH*HEIGHT || (packed_pixels==0 && pixel_x[2:0]!=0) ||
                   (packed_pixels!=0 && (pixel_y!=run_y || pixel_x!=run_x+packed_pixels)))begin
                    error<=1;opened<=0;packed_pixels<=0;
                end else begin
                    pixels<=pixels+1'b1;packed_data[packed_pixels*32+:32]<={8'd0,pixel_rgb};
                    if(packed_pixels==0)begin run_x<=pixel_x;run_y<=pixel_y;end
                    if(packed_pixels==7)begin
                        awaddr<=(bank?BASE1:BASE0)+pixel_y*WIDTH+pixel_x-7;
                        awvalid<=1;write_active<=1;address_sent<=0;completion_seen<=0;packed_pixels<=0;
                    end else packed_pixels<=packed_pixels+1'b1;
                end
            end
            if(abort)begin
                // Native writes already issued must drain to keep arbitration
                // ownership valid. Cancel only subsequent JPEG pixels.
                opened<=0;packed_pixels<=0;frame_done<=0;
            end
        end
    end
    // Native controllers have no write-valid input. Data stays stable from
    // AW through WLAST; wready is intentionally not used as completion.
    wire unused_wready=wready;
endmodule
