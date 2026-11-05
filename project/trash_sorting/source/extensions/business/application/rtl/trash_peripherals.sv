// Camera-driven quiz peripherals; TEST_MODE=1 enables standalone diagnostics.
module trash_peripherals #(
    parameter integer CLK_HZ=50000000,
    parameter integer DEBOUNCE_MS=20,
    parameter integer OPEN_MS=5000,
    parameter integer TEST_MODE=0,
    parameter logic [3:0] SERVO_REVERSED_MASK=4'b0000
)(
    input wire clk,rst,start_ready,
    input wire [3:0] key_n,
    input wire detect_event,bin_valid,
    input wire [2:0] bin_code,
    output wire [3:0] servo_pwm,open_state,
    output wire voice_valid,
    output wire [2:0] voice_asset_id,
    output wire [127:0] snapshot
);
    wire [3:0] key_event,servo_trigger;
    key_debounce4 #(.CLK_HZ(CLK_HZ),.DEBOUNCE_MS(DEBOUNCE_MS)) buttons(
        .clk(clk),.rst(rst),.key_n(key_n),.key_event(key_event));
    trash_quiz_controller #(.TEST_MODE(TEST_MODE)) control(
        .clk(clk),.rst(rst),.start_ready(start_ready),.key_event(key_event),
        .servo_open_state(open_state),.detect_event(detect_event),
        .bin_valid(bin_valid),.bin_code(bin_code),.servo_trigger(servo_trigger),
        .voice_valid(voice_valid),.voice_asset_id(voice_asset_id),.snapshot(snapshot));
    servo_pwm4 #(.CLK_HZ(CLK_HZ),.OPEN_FRAMES((OPEN_MS*50+999)/1000),
        .REVERSED_MASK(SERVO_REVERSED_MASK)) servos(
        .clk(clk),.rst(rst),.trigger(servo_trigger),.pwm(servo_pwm),.open_state(open_state));
endmodule
