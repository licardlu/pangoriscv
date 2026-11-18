`timescale 1ns/1ps
module trash_voice_rom_full_tb;
    reg clk = 0; always #5 clk=~clk;
    reg rst=1, req=0;
    reg [2:0] id=0;
    wire valid,last,busy;
    wire [15:0] pcm;
    reg [7:0] reference [0:181891];
`ifdef SYNTHESIS
    initial $readmemh("../../extensions/business/application/assets/audio_rom/voice_pcm8.hex",reference);
`else
    initial $readmemh("../../assets/audio_rom/voice_pcm8.hex",reference);
`endif
    trash_voice_rom_player #(.ROM_FILE("../../assets/audio_rom/voice_pcm8.hex")) dut(
        .clk(clk),.rst(rst),.request_valid(req),.request_asset_id(id),
        .sample_ready(1'b1),.sample_valid(valid),.sample_pcm(pcm),.sample_last(last),.busy(busy));
    integer count=0, start_addr=0, clip_length=0, asset, repetitions;
    reg checking=0;
    always @(posedge clk) if(!rst && checking && valid) begin
        if(pcm !== {reference[start_addr + count/repetitions],8'b0})
            $fatal(1,"ROM mismatch at asset %0d sample %0d: %h",asset,count,pcm);
        if(last !== (count == clip_length*repetitions-1))
            $fatal(1,"ROM last marker mismatch at sample %0d",count);
        count=count+1;
    end
    initial begin
        repeat(3) @(negedge clk); rst=0;
        for(asset=1;asset<=7;asset=asset+1) begin
            repetitions=asset>=4?4:3;
            case(asset)
                1: begin start_addr=0; clip_length=37192; end
                2: begin start_addr=37192; clip_length=40392; end
                3: begin start_addr=77584; clip_length=37992; end
                4: begin start_addr=115576; clip_length=15340; end
                5: begin start_addr=130916; clip_length=15858; end
                6: begin start_addr=146774; clip_length=15735; end
                7: begin start_addr=162509; clip_length=19383; end
            endcase
            count=0; checking=1;
            @(negedge clk); id=asset; req=1;
            @(negedge clk); req=0;
            wait(!busy); @(negedge clk);
            if(count != clip_length*repetitions) $fatal(1,"Wrong full-clip length %0d",count);
            checking=0;
        end
        $display("PASS: every PCM sample from all 7 real WAV ROM assets is delivered at its exact 16kHz/12kHz repeat rate with correct final marker");
        $finish;
    end
    initial begin #10000000; $fatal(1,"Timeout"); end
endmodule
