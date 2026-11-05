`timescale 1ns/1ps
module servo_key_controller_tb;
    logic clk = 0;
    logic rst = 1;
    logic [3:0] key_n = 4'hf;
    wire [3:0] servo_pwm;
    wire [3:0] open_state;
    wire [3:0] key_event;
    integer n;

    always #5 clk = ~clk;

    // 10 kHz simulation clock, 20-cycle debounce, six servo frames open.
    servo_key_controller #(
        .CLK_HZ(10000), .DEBOUNCE_MS(2), .OPEN_MS(120)
    ) dut (.*);

    task wait_frames(input integer count);
        integer k;
        begin
            for (k = 0; k < count * 200; k = k + 1) @(posedge clk);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        wait_frames(1);
        if (open_state !== 4'b0000)
            $fatal(1, "all lids must start closed");

        // A short key bounce is shorter than the debounce window and ignored.
        @(negedge clk); key_n[1] = 0;
        repeat (7) @(negedge clk);
        key_n[1] = 1;
        wait_frames(1);
        if (open_state !== 4'b0000)
            $fatal(1, "short key bounce triggered a servo");

        // Key 1 -> green PWM[0], key 3 -> gray PWM[2].
        @(negedge clk); key_n[0] = 0; key_n[2] = 0;
        repeat (30) @(negedge clk);
        key_n[0] = 1; key_n[2] = 1;
        wait_frames(2);
        if (open_state !== 4'b0101)
            $fatal(1, "key 1/3 mapping or opening failed: %b", open_state);
        wait_frames(3);
        if (open_state !== 4'b0101)
            $fatal(1, "servo closed before configured open duration: %b", open_state);
        wait_frames(4);
        if (open_state !== 4'b0000)
            $fatal(1, "servo did not auto-close after configured duration: %b", open_state);

        // Holding key 4 beyond the open duration must not retrigger it.
        @(negedge clk); key_n[3] = 0;
        repeat (30) @(negedge clk);
        wait_frames(2);
        if (open_state !== 4'b1000)
            $fatal(1, "key 4 must map to blue PWM[3]: %b", open_state);
        wait_frames(8);
        if (open_state !== 4'b0000)
            $fatal(1, "held key retriggered after timeout: %b", open_state);
        key_n[3] = 1;

        $display("TEST_PASS servo_key_controller debounce mapping one-shot and auto-close");
        $finish;
    end

    initial begin
        repeat (100000) @(posedge clk);
        $fatal(1, "timeout");
    end
endmodule
