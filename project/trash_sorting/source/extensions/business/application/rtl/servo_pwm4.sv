// FPGA replacement for stm32_reference/Core/Src/main.c:Servo_Task.
// 20ms frames, 50 steps (20us/frame), 5s at 90 degrees, 50 steps closed.
// Uncalibrated logical endpoints: 500us=closed, 1500us=open. Board callers
// MUST supply the installed servo directions; pulse width alone is not lid angle.
// open_state stays asserted until the closing movement has finished.
module servo_pwm4 #(
    parameter integer CLK_HZ = 120461538,
    parameter integer OPEN_FRAMES = 250,
    parameter logic [3:0] REVERSED_MASK = 4'b0000,
    parameter integer MOVE_FRAMES = 50,
    parameter integer REARM_FRAMES = 5
) (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] trigger,
    output logic [3:0] pwm,
    output wire  [3:0] open_state
);
    localparam integer PERIOD = CLK_HZ / 50;
    localparam integer PULSE_0 = CLK_HZ / 2000;
    localparam integer PULSE_90 = (CLK_HZ * 3) / 2000;
    localparam integer STEP_TICKS = (PULSE_90 - PULSE_0) / MOVE_FRAMES;
    localparam integer STEP_REMAINDER = (PULSE_90 - PULSE_0) % MOVE_FRAMES;
    localparam integer CW = (PERIOD < 2) ? 1 : $clog2(PERIOD);
    localparam integer FW = (OPEN_FRAMES < 2) ? 1 : $clog2(OPEN_FRAMES + 1);
    localparam integer MW = (MOVE_FRAMES < 2) ? 1 : $clog2(MOVE_FRAMES + 1);
    localparam integer RW = (REARM_FRAMES < 2) ? 1 : $clog2(REARM_FRAMES + 1);
    localparam logic [1:0] CLOSED=0, OPENING=1, HOLDING=2, CLOSING=3;
    logic [CW-1:0] period_count;
    logic [1:0] state [0:3];
    logic [MW-1:0] position [0:3];
    logic [FW-1:0] remaining [0:3];
    logic [RW-1:0] rearm [0:3];
    logic [3:0] trigger_d, trigger_pending;
    wire [CW-1:0] pulse_ticks [0:3];
    genvar ch;
    generate for (ch=0; ch<4; ch=ch+1) begin: channel
        // Clamp the endpoint: fractional clock rates still take 50 steps.
        // At the board's 27MHz each step is exactly 540 clocks/20us.
        wire [CW-1:0] normal_ticks = (position[ch] == MOVE_FRAMES) ?
            PULSE_90 : PULSE_0 + position[ch] * STEP_TICKS +
                (position[ch] * STEP_REMAINDER) / MOVE_FRAMES;
        assign pulse_ticks[ch] = REVERSED_MASK[ch] ?
            PULSE_0 + PULSE_90 - normal_ticks : normal_ticks;
        assign open_state[ch] = (state[ch] != CLOSED);
    end endgenerate
    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            period_count <= '0;
            trigger_d <= '0;
            trigger_pending <= '0;
            pwm <= '0;
            for (i=0; i<4; i=i+1) begin
                state[i] <= CLOSED;
                position[i] <= '0;
                remaining[i] <= '0;
                rearm[i] <= REARM_FRAMES;
            end
        end else begin
            trigger_d <= trigger;
            for (i=0; i<4; i=i+1) begin
                // Capture short requests between frame boundaries. Busy
                // requests never restart the timer or queue another opening.
                if (state[i] == CLOSED &&
                    trigger[i] && !trigger_d[i]) trigger_pending[i] <= 1'b1;
                pwm[i] <= (period_count < pulse_ticks[i]);
            end
            if (period_count == PERIOD-1) begin
                period_count <= '0;
                for (i=0; i<4; i=i+1) begin
                    case (state[i])
                        CLOSED: begin
                            if (!trigger[i] && rearm[i] < REARM_FRAMES)
                                rearm[i] <= rearm[i] + 1'b1;
                            else if (trigger[i] && rearm[i] < REARM_FRAMES)
                                rearm[i] <= '0;
                            if (rearm[i] == REARM_FRAMES &&
                                (trigger_pending[i] || (trigger[i] && !trigger_d[i]))) begin
                                state[i] <= OPENING;
                                rearm[i] <= '0;
                                trigger_pending[i] <= 1'b0;
                            end
                        end
                        OPENING: begin
                            position[i] <= position[i] + 1'b1;
                            if (position[i] == MOVE_FRAMES-1) begin
                                state[i] <= HOLDING;
                                remaining[i] <= OPEN_FRAMES;
                            end
                        end
                        HOLDING: begin
                            if (remaining[i] > 1) remaining[i] <= remaining[i] - 1'b1;
                            else begin
                                // Start closing after exactly 250 complete
                                // endpoint frames (5s), without an extra frame.
                                position[i] <= position[i] - 1'b1;
                                state[i] <= CLOSING;
                            end
                        end
                        CLOSING: begin
                            if (position[i] != 0) position[i] <= position[i] - 1'b1;
                            else begin
                                // Report completion after a full frame at 0deg.
                                state[i] <= CLOSED;
                                rearm[i] <= '0;
                            end
                        end
                        default: begin
                            state[i] <= CLOSED;
                            position[i] <= '0;
                            rearm[i] <= '0;
                        end
                    endcase
                end
            end else period_count <= period_count + 1'b1;
        end
    end
endmodule
