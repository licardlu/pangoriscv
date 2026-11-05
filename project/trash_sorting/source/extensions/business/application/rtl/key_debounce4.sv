// Four active-low asynchronous buttons. Each stable press generates one pulse.
module key_debounce4 #(
    parameter integer CLK_HZ = 50000000,
    parameter integer DEBOUNCE_MS = 20
)(
    input logic clk, rst,
    input logic [3:0] key_n,
    output logic [3:0] key_event
);
    // Split the multiply so 120 MHz * 20 ms cannot overflow a signed integer.
    localparam integer CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS +
        (((CLK_HZ % 1000) * DEBOUNCE_MS + 999) / 1000);
    localparam integer CW = (CYCLES < 2) ? 1 : $clog2(CYCLES + 1);
    (* ASYNC_REG="TRUE" *) logic [3:0] key_meta, key_sync;
    logic [3:0] pressed;
    logic [CW-1:0] count[0:3];
    integer i;
    always_ff @(posedge clk) begin
        if(rst) begin
            key_meta <= 4'hf; key_sync <= 4'hf; pressed <= 0; key_event <= 0;
            for(i=0;i<4;i=i+1) count[i] <= 0;
        end else begin
            key_meta <= key_n; key_sync <= key_meta; key_event <= 0;
            for(i=0;i<4;i=i+1) begin
                if((!key_sync[i]) == pressed[i]) count[i] <= 0;
                else if(count[i] >= CYCLES-1) begin
                    count[i] <= 0; pressed[i] <= !key_sync[i];
                    if(!key_sync[i]) key_event[i] <= 1;
                end else count[i] <= count[i]+1'b1;
            end
        end
    end
endmodule
