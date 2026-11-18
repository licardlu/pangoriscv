// KEY0 owns three pages. The legacy serial debug command can still show
// the score page; long press preserves the existing saved-score timer.
module media_page_router(
    input wire clk,rst,next_page,long_press,debug_page_async,
    input tri0 toggle_recognition,
    output wire [1:0] page,
    output reg benchmark_start_toggle
);
    reg [1:0] selected;
    (* ASYNC_REG="TRUE" *) reg [1:0] debug_sync;
    assign page=debug_sync[1]?2'd1:selected;
    always @(posedge clk)begin
        if(rst)begin selected<=0;benchmark_start_toggle<=0;debug_sync<=0;end
        else begin
            debug_sync<={debug_sync[0],debug_page_async};
            if(toggle_recognition)selected<=selected==0?2'd2:2'd0;
            if(next_page)begin
                selected<=selected==2?2'd0:selected+1'b1;
                if(selected==0)benchmark_start_toggle<=!benchmark_start_toggle;
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
