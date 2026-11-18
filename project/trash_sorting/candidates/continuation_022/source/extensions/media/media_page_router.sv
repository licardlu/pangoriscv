// Single click starts/stops recognition. Double click toggles score/animation
// from either idle or recognition. Serial debug/long press can show the demo.
module media_page_router #(
    parameter [1:0] RESET_PAGE=0,
    parameter integer AUTO_ONEHOT=0
)(
    input wire clk,rst,next_page,long_press,debug_page_async,
    input tri0 toggle_recognition,
    input tri0 [2:0] automatic_request_async,
    output reg automatic_blocked,
    output wire [1:0] page,
    output reg benchmark_start_toggle
);
    reg [1:0] selected;
    (* ASYNC_REG="TRUE" *) reg [1:0] debug_sync;
    (* ASYNC_REG="TRUE" *) reg [2:0] auto_meta,auto_sync;
    wire [1:0] auto_command=AUTO_ONEHOT ?
        (auto_sync==3'b001 ? 2'd0:auto_sync==3'b010 ? 2'd1:
         auto_sync==3'b100 ? 2'd2:2'd3) : auto_sync[1:0];
    assign page=debug_sync[1]?2'd1:selected;
    always @(posedge clk)begin
        if(rst)begin selected<=RESET_PAGE;benchmark_start_toggle<=0;debug_sync<=0;
            auto_meta<=AUTO_ONEHOT?3'b001:0;auto_sync<=AUTO_ONEHOT?3'b001:0;automatic_blocked<=0;end
        else begin
            debug_sync<={debug_sync[0],debug_page_async};
            auto_meta<=automatic_request_async;auto_sync<=auto_meta;
            if(auto_command==0)automatic_blocked<=0;
            // Auto idle/wake uses the existing smooth display transition.
            // Manual keys take priority and block auto until explicitly disabled.
            if(!automatic_blocked && selected!=1 && !debug_sync[1])begin
                if(auto_command==1)selected<=0;
                if(auto_command==2)selected<=2;
            end
            if(toggle_recognition || next_page || long_press)automatic_blocked<=1;
            if(toggle_recognition)selected<=selected==0?2'd2:2'd0;
            if(next_page)begin
                selected<=selected==1?2'd2:2'd1;
                if(selected!=1)benchmark_start_toggle<=!benchmark_start_toggle;
            end
            if(long_press)begin selected<=1;benchmark_start_toggle<=!benchmark_start_toggle;end
        end
    end
endmodule

// The navigation request stops recognition immediately; only the displayed
// page is delayed. No frame storage and no changes to HS/VS/DE timing.
module media_page_transition(
    input wire clk,rst,frame_start,
    input wire [2:0] request_onehot_async,
    input wire [23:0] rgb_in,
    output reg [1:0] display_page,
    output wire [23:0] rgb_out
);
    (* ASYNC_REG="TRUE" *) reg [2:0] request_meta,request_sync;
    reg [1:0] target;
    reg [2:0] brightness;
    reg vs_old,settle;
    always @(posedge clk)begin
        if(rst)begin
            request_meta<=1;request_sync<=1;target<=0;display_page<=0;
            brightness<=4;vs_old<=0;settle<=0;
        end else begin
            request_meta<=request_onehot_async;request_sync<=request_meta;
            vs_old<=frame_start;
            case(request_sync)
                3'b001:target<=0;
                3'b010:target<=1;
                3'b100:target<=2;
                default:; // Retain the last valid page through CDC skew.
            endcase
            if(frame_start&&!vs_old)begin
                if(settle)settle<=0;
                else if(target!=display_page)begin
                    if(brightness!=0)brightness<=brightness-1'b1;
                    else begin display_page<=target;settle<=1;end
                end else if(brightness<4)brightness<=brightness+1'b1;
            end
        end
    end
    function automatic [7:0] dim(input [7:0] value,input [2:0] level);
        case(level)
            0:dim=0;
            1:dim=value>>2;
            2:dim=value>>1;
            3:dim=value-(value>>2);
            default:dim=value;
        endcase
    endfunction
    assign rgb_out={dim(rgb_in[23:16],brightness),dim(rgb_in[15:8],brightness),dim(rgb_in[7:0],brightness)};
endmodule
