// Four independent 50 Hz hobby-servo outputs for the sorting bins.
//
// The board clock is a parameter because this block is also useful in the
// standalone peripheral test.  A trigger opens one lid to 90 degrees for
// OPEN_FRAMES periods, then returns it to 0 degrees.  Pulse widths follow the
// supplied STM32 test: 0.5 ms = 0 degrees and 1.5 ms = 90 degrees.
// A reversed mechanical installation swaps these closed/open pulse widths;
// the signal remains an active-high 50 Hz pulse, never a waveform inversion.
module servo_pwm4 #(
    parameter integer CLK_HZ = 120461538,
    parameter integer OPEN_FRAMES = 250,      // 5 seconds at 50 Hz
    parameter logic [3:0] REVERSED_MASK = 4'b0000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] trigger,
    output logic [3:0] pwm,
    output logic [3:0] open_state
);
    localparam integer PERIOD = CLK_HZ / 50;
    localparam integer PULSE_0 = CLK_HZ / 2000; // 0.5 ms
    localparam integer PULSE_90 = (CLK_HZ * 3) / 2000; // 1.5 ms
    localparam integer CW = (PERIOD < 2) ? 1 : $clog2(PERIOD);
    localparam integer FW = (OPEN_FRAMES < 2) ? 1 : $clog2(OPEN_FRAMES + 1);
    logic [CW-1:0] period_count;
    logic [FW-1:0] remaining [0:3];
    logic [3:0] trigger_d;
    logic [3:0] trigger_pending;
    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            period_count <= '0;
            trigger_d <= '0;
            trigger_pending <= '0;
            pwm <= '0;
            open_state <= '0;
            for (i = 0; i < 4; i = i + 1) remaining[i] <= '0;
        end else begin
            trigger_d <= trigger;
            for (i = 0; i < 4; i = i + 1)
                if (trigger[i] && !trigger_d[i])
                    trigger_pending[i] <= 1'b1;
            if (period_count == PERIOD-1) begin
                period_count <= '0;
                for (i = 0; i < 4; i = i + 1) begin
                    if (trigger_pending[i] || (trigger[i] && !trigger_d[i])) begin
                        remaining[i] <= OPEN_FRAMES;
                        trigger_pending[i] <= 1'b0;
                    end else if (remaining[i] != 0)
                        remaining[i] <= remaining[i] - 1'b1;
                end
            end else begin
                period_count <= period_count + 1'b1;
            end
            for (i = 0; i < 4; i = i + 1)
                open_state[i] <= (remaining[i] != 0);
            for (i = 0; i < 4; i = i + 1)
                pwm[i] <= (period_count < ((open_state[i] ^ REVERSED_MASK[i]) ? PULSE_90 : PULSE_0));
        end
    end
endmodule
