// Drain a complete SD sector, retaining only its file slice. Partial JPEG
// words survive sector boundaries. CRC covers only actual compressed bytes.
module media_sector_stream(
    input wire clk,rst,frame_start,sector_start,frame_end,abort,
    input wire [8:0] sector_skip,input wire [9:0] sector_length,
    output wire busy,output reg sector_done,error,finalized,
    output wire [31:0] crc32,
    output wire read_req,input wire read_ready,read_valid,read_error,
    input wire [31:0] read_data,
    output reg out_valid,input wire out_ready,
    output reg [31:0] out_data,output reg out_last
);
    localparam IDLE=0,REQUEST=1,WAIT_WORD=2,BYTES=3,FLUSH=4,TERMINATE=5,FINISH=6;
    reg [2:0] state;
    reg opened;
    reg [8:0] slice_start;
    reg [9:0] slice_end;
    reg [6:0] word_number;
    reg [1:0] byte_number,packed_bytes;
    reg [31:0] word_hold,packed_word,crc;
    wire [8:0] position={word_number,byte_number};
    wire retain=position>=slice_start && {1'b0,position}<slice_end;
    wire [7:0] byte_value=word_hold[byte_number*8+:8];
    wire output_space=!out_valid||out_ready;
    assign busy=state!=IDLE;
    assign read_req=state==REQUEST;
    assign crc32=~crc;
    function automatic [31:0] update_crc(input [31:0] old,input [7:0] value);
        reg [31:0] c;integer b;
        begin c=old^value;for(b=0;b<8;b=b+1)c=(c>>1)^((c&1)?32'hedb88320:32'd0);update_crc=c;end
    endfunction
    always @(posedge clk)begin
        if(rst||abort)begin
            state<=IDLE;opened<=0;slice_start<=0;slice_end<=0;word_number<=0;byte_number<=0;
            packed_bytes<=0;word_hold<=0;packed_word<=0;crc<=32'hffffffff;
            out_valid<=0;out_data<=0;out_last<=0;sector_done<=0;error<=0;finalized<=0;
        end else begin
            sector_done<=0;
            if(out_valid&&out_ready)out_valid<=0;
            if(frame_start)begin
                if(state!=IDLE || out_valid)error<=1;
                else begin opened<=1;packed_bytes<=0;packed_word<=0;crc<=32'hffffffff;error<=0;finalized<=0;end
            end
            if(sector_start)begin
                if(state!=IDLE || !opened || !sector_length || {1'b0,sector_skip}+sector_length>512)error<=1;
                else begin
                    slice_start<=sector_skip;slice_end<={1'b0,sector_skip}+sector_length;
                    word_number<=0;byte_number<=0;state<=REQUEST;
                end
            end
            if(frame_end)begin
                if(state!=IDLE || !opened)error<=1;
                else begin state<=FLUSH;opened<=0;end
            end
            case(state)
                REQUEST:if(read_ready)state<=WAIT_WORD;
                WAIT_WORD:if(read_valid)begin
                    if(read_error)begin error<=1;state<=IDLE;opened<=0;end
                    else begin word_hold<=read_data;byte_number<=0;state<=BYTES;end
                end
                BYTES:if(output_space)begin
                    if(retain)begin
                        crc<=update_crc(crc,byte_value);
                        if(packed_bytes==3)begin
                            out_data<={byte_value,packed_word[23:0]};out_valid<=1;out_last<=0;
                            packed_bytes<=0;packed_word<=0;
                        end else begin
                            packed_word[packed_bytes*8+:8]<=byte_value;packed_bytes<=packed_bytes+1'b1;
                        end
                    end
                    if(byte_number==3)begin
                        if(word_number==127)begin state<=IDLE;sector_done<=1;end
                        else begin word_number<=word_number+1'b1;state<=REQUEST;end
                    end else byte_number<=byte_number+1'b1;
                end
                FLUSH:if(output_space)begin
                    if(packed_bytes!=0)begin out_data<=packed_word;out_valid<=1;out_last<=0;end
                    state<=TERMINATE;
                end
                TERMINATE:if(output_space)begin out_data<=0;out_valid<=1;out_last<=1;state<=FINISH;end
                FINISH:if(out_valid&&out_ready)begin finalized<=1;state<=IDLE;end
                default:;
            endcase
        end
    end
endmodule
