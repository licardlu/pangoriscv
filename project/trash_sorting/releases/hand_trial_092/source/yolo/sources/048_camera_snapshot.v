// Capture one immutable RGB565 frame at integer decimation. The CPU owns it
// until it requests another frame. Both RAM ports have synchronous reads/writes.
`timescale 1ns/1ps
module camera_snapshot #(
    parameter integer IN_W=1280, IN_H=720, STEP=4,
    parameter integer OUT_W=IN_W/STEP, OUT_H=IN_H/STEP
) (
    input wire cpu_clk,cpu_rstn,request,
    input wire [15:0] read_address,
    output reg [15:0] read_data,
    output reg busy,ready,error,
    output reg [15:0] frame_id,
    input wire cam_clk,cam_rstn,vsync,de,
    input wire [15:0] pixel
);
    reg [15:0] memory[0:OUT_W*OUT_H-1];
    reg req_toggle,done_toggle;
    reg [1:0] req_sync,done_sync;
    reg done_seen,req_seen,pending,active,vs_d,de_d,cam_error;
    reg [15:0] x,y,write_index,frame_counter,frozen_id;
    wire frame_start=vs_d && !vsync;
    always @(posedge cpu_clk) begin
        if(read_address<OUT_W*OUT_H) read_data<=memory[read_address];
        else read_data<=0;
        if(!cpu_rstn) begin
            req_toggle<=0;done_sync<=0;done_seen<=0;
            busy<=0;ready<=0;error<=0;frame_id<=0;
        end else begin
            done_sync<={done_sync[0],done_toggle};
            if(request && !busy) begin
                req_toggle<=!req_toggle;busy<=1;ready<=0;error<=0;
            end
            if(done_sync[1]!=done_seen) begin
                done_seen<=done_sync[1];busy<=0;
                error<=cam_error;ready<=!cam_error;frame_id<=frozen_id;
            end
        end
    end
    always @(posedge cam_clk) begin
        if(!cam_rstn) begin
            req_sync<=0;req_seen<=0;done_toggle<=0;pending<=0;active<=0;
            vs_d<=0;de_d<=0;x<=0;y<=0;write_index<=0;
            cam_error<=0;frame_counter<=0;frozen_id<=0;
        end else begin
            req_sync<={req_sync[0],req_toggle};vs_d<=vsync;de_d<=de;
            if(req_sync[1]!=req_seen) begin
                req_seen<=req_sync[1];pending<=1;
            end
            if(frame_start) begin
                frame_counter<=frame_counter+1'b1;
                x<=0;y<=0;
                if(active) begin
                    active<=0;cam_error<=1;done_toggle<=!done_toggle;
                end else if(pending) begin
                    pending<=0;active<=1;write_index<=0;
                    frozen_id<=frame_counter;cam_error<=0;
                end
            end else if(active) begin
                if(de) begin
                    x<=x+1'b1;
                    if(x<IN_W && y<IN_H && x%STEP==0 && y%STEP==0) begin
                        memory[write_index]<=pixel;
                        write_index<=write_index+1'b1;
                        if(write_index==OUT_W*OUT_H-1) begin
                            active<=0;done_toggle<=!done_toggle;
                        end
                    end
                end
                if(de_d && !de) begin x<=0;y<=y+1'b1;end
            end
        end
    end
endmodule
