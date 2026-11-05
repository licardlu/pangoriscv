// Normal sessions latch the camera answer, then wait for a board key.
// Keys/bin codes: 1 green, 2 red, 3 gray, 4 blue.
// TEST_MODE=1: fixed correct answer is key 1 / green. Every answer opens the
// correct green lid, with correct/wrong audio selected by the answer key.
// When that servo actually closes after five seconds, prompt again.
// TEST_MODE=0: camera bin 1..4 supplies the correct answer for each session.
module trash_quiz_controller #(
    parameter integer TEST_MODE = 0
)(
    input logic clk, rst, start_ready,
    input logic [3:0] key_event,
    input logic [3:0] servo_open_state,
    input logic detect_event, bin_valid,
    input logic [2:0] bin_code,
    output logic [3:0] servo_trigger,
    output logic voice_valid,
    output logic [2:0] voice_asset_id,
    output logic [127:0] snapshot
);
    localparam [2:0] IDLE=0, WAIT_ANSWER=1, ANSWERED=2;
    logic [2:0] state;
    logic [1:0] correct, choice;
    logic startup,opened_seen;
    logic [1:0] key_index;
    always_comb begin
        if(key_event[0]) key_index=0;
        else if(key_event[1]) key_index=1;
        else if(key_event[2]) key_index=2;
        else key_index=3;
        snapshot=0;
        snapshot[2:0]=state;
        snapshot[105:104]=correct;
        snapshot[113:112]=choice;
        snapshot[119]=(state==ANSWERED);
    end
    always_ff @(posedge clk) begin
        if(rst) begin
            state <= TEST_MODE ? WAIT_ANSWER : IDLE;
            correct<=0; choice<=0; startup<=1; opened_seen<=0;
            servo_trigger<=0; voice_valid<=0; voice_asset_id<=0;
        end else begin
            servo_trigger<=0; voice_valid<=0;
            if(start_ready && startup) begin
                startup<=0;
                if(TEST_MODE) begin voice_valid<=1; voice_asset_id<=1; end
            end
            if(start_ready && !startup) case(state)
                IDLE: if(detect_event && bin_valid && bin_code>=1 && bin_code<=4) begin
                    correct<=bin_code-1'b1; state<=WAIT_ANSWER;
                    voice_valid<=1; voice_asset_id<=1;
                end
                WAIT_ANSWER: if(|key_event) begin
                    choice<=key_index; state<=ANSWERED;
                    // Always open the correct bin, including on wrong answers.
                    // Direct four-channel diagnostics use servo_key_controller.
                    servo_trigger<=4'b0001<<correct;
                    voice_valid<=1;
                    voice_asset_id<=(key_index==correct)?3'd2:3'd3;
                    opened_seen<=0;
                end
                ANSWERED: begin
                    if(|servo_open_state) opened_seen<=1;
                    // Use feedback, not a second independent 5s timer. PWM
                    // opens on its next 20ms boundary; a parallel timer could
                    // otherwise repeat the prompt before the lid has closed.
                    if(opened_seen && !(|servo_open_state)) begin
                        opened_seen<=0;
                        if(TEST_MODE) begin
                            state<=WAIT_ANSWER;correct<=0;
                            voice_valid<=1;voice_asset_id<=1;
                        end else state<=IDLE;
                    end
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
