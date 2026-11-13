// Standalone hardware diagnostic: KEY1 green, KEY2 red, KEY3 gray, KEY4 blue.
// The exact same motion/debounce RTL is used by the complete application.
module servo_key_test_top #(
    parameter integer CLK_HZ=27000000,
    parameter integer POR_CYCLES=270000,
    parameter integer DEBOUNCE_MS=20
)(
    input wire sys_clk,
    input wire [3:0] key_n,
    output wire [3:0] servo_pwm
);
    localparam integer PW=(POR_CYCLES<2)?1:$clog2(POR_CYCLES);
    reg [PW-1:0] por_count=0;
    reg [1:0] reset_release=0;
    always @(posedge sys_clk) begin
        if(por_count<POR_CYCLES-1) begin
            por_count<=por_count+1'b1;
            reset_release<=0;
        end else reset_release<={reset_release[0],1'b1};
    end
    wire [3:0] open_state,key_event;
    // User tested ALL FOUR: 500us physically opens, 1500us closes the lids.
    // Calibrate all channels, including gray; old STM32 color masks are stale.
    // Logical position still starts CLOSED; physical PWM starts at 1500us.
    servo_key_controller #(.CLK_HZ(CLK_HZ),.DEBOUNCE_MS(DEBOUNCE_MS),.OPEN_MS(5000),
        .SERVO_REVERSED_MASK(4'b1111)) controller(
        .clk(sys_clk),.rst(!reset_release[1]),.key_n(key_n),
        .servo_pwm(servo_pwm),.open_state(open_state),.key_event(key_event));
endmodule
