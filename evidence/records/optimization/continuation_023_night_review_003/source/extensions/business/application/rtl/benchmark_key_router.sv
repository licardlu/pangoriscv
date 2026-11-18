// Dedicated KEY0 (C22), navigation only; never drives global reset.
module benchmark_key_router #(
    parameter integer CLK_HZ=27000000, DEBOUNCE_MS=20, LONG_PRESS_MS=2000,
    parameter integer DOUBLE_CLICK_MS=350
)(input wire clk,rst,key0_n,output reg toggle_page,output reg start_reference,
  output reg toggle_recognition);
    localparam integer DB=(CLK_HZ/1000)*DEBOUNCE_MS;
    localparam integer DW=$clog2(DB+1);
    localparam integer LONG=(CLK_HZ/1000)*LONG_PRESS_MS;
    localparam integer LW=$clog2(LONG+1);
    localparam integer DOUBLE=(CLK_HZ/1000)*DOUBLE_CLICK_MS;
    localparam integer CW=$clog2(DOUBLE+1);
    (* ASYNC_REG="TRUE" *) reg meta,sync;
    reg held,long_sent;
    reg [DW-1:0] count;
    reg [LW-1:0] hold_count;
    reg pending_click,second_click;
    reg [CW-1:0] click_count;
    always @(posedge clk) begin
        if(rst) begin
            meta<=1;sync<=1;held<=0;count<=0;toggle_page<=0;
            start_reference<=0;hold_count<=0;long_sent<=0;
            toggle_recognition<=0;pending_click<=0;second_click<=0;click_count<=0;
        end else begin
            meta<=key0_n;sync<=meta;toggle_page<=0;start_reference<=0;toggle_recognition<=0;
            if(pending_click && !second_click && !held && sync)begin
                if(click_count>=DOUBLE-1)begin
                    pending_click<=0;click_count<=0;toggle_recognition<=1;
                end else click_count<=click_count+1'b1;
            end
            if(held&&!long_sent)begin
                if(hold_count>=LONG-1)begin
                    start_reference<=1;long_sent<=1;pending_click<=0;second_click<=0;click_count<=0;
                end
                else hold_count<=hold_count+1'b1;
            end
            if((!sync)==held)count<=0;
            else if(count>=DB-1)begin
                count<=0;held<=!sync;
                if(!sync)begin
                    hold_count<=0;long_sent<=0;
                    if(pending_click)second_click<=1;
                end
                else begin
                    if(!long_sent && hold_count<LONG-1)begin
                        if(second_click)begin
                            toggle_page<=1;pending_click<=0;second_click<=0;click_count<=0;
                        end else begin pending_click<=1;click_count<=0;end
                    end
                    hold_count<=0;
                end
            end else count<=count+1'b1;
        end
    end
endmodule
