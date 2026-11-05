// Active-low board keys with per-key synchronizers and stable-time debounce.
// key_n[0..3] map to blue, gray, red, and green servo outputs respectively.
module servo_key_controller #(
    parameter integer CLK_HZ = 120461538,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer OPEN_MS = 5000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] key_n,
    output logic [3:0] servo_pwm,
    output logic [3:0] open_state,
    output logic [3:0] key_event
);
    localparam integer OPEN_FRAMES = (OPEN_MS * 50 + 999) / 1000;
    key_debounce4 #(.CLK_HZ(CLK_HZ),.DEBOUNCE_MS(DEBOUNCE_MS)) keys(
        .clk(clk),.rst(rst),.key_n(key_n),.key_event(key_event));

    servo_pwm4 #(.CLK_HZ(CLK_HZ), .OPEN_FRAMES(OPEN_FRAMES)) servo_bank (
        .clk(clk), .rst(rst), .trigger(key_event),
        .pwm(servo_pwm), .open_state(open_state)
    );
endmodule
