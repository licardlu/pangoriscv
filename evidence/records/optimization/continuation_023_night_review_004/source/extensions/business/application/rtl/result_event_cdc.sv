// Atomic inference event transfer. One in-flight event and one pending slot.
// Producer results are separated by a complete inference; minimum supported
// interval is 64 cycles of the slower clock. Overflow is explicit for misuse.
module result_event_cdc #(
    parameter integer W=9
)(
    input wire sclk,srst,event_in,
    input wire [W-1:0] payload_in,
    output reg overflow,
    input wire dclk,drst,
    output reg event_out,
    output reg [W-1:0] payload_out
);
    reg [W-1:0] hold,pending_data;
    reg req,ack,pending;
    (* ASYNC_REG="TRUE" *) reg ack1,ack2,req1,req2;
    wire busy=req!=ack2;
    always @(posedge sclk) begin
        if(srst) begin
            hold<=0;pending_data<=0;req<=0;pending<=0;
            ack1<=0;ack2<=0;overflow<=0;
        end else begin
            ack1<=ack;ack2<=ack1;
            if(event_in) begin
                if(pending && busy) overflow<=1;
                pending_data<=payload_in;
                pending<=1;
            end
            if(!busy && pending) begin
                hold<=pending_data;
                req<=~req;
                pending<=event_in;
            end
        end
    end
    always @(posedge dclk) begin
        if(drst) begin
            req1<=0;req2<=0;ack<=0;event_out<=0;payload_out<=0;
        end else begin
            req1<=req;req2<=req1;
            event_out<=0;
            if(req2!=ack) begin
                payload_out<=hold;
                event_out<=1;
                ack<=req2;
            end
        end
    end
endmodule
