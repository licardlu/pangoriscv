// Join the CPU register window and autonomous sector drain onto MMC AXI-Lite.
// Keep AW/W independent and retain payload until B; guard card writes in RTL.
module media_mmc_bus(
    input wire clk,rst,host_valid,output wire host_ready,
    input wire host_write,input wire [7:0] host_address,input wire [31:0] host_data,
    output reg host_done,host_error,output reg [31:0] host_result,
    input wire stream_req,output wire stream_ready,
    output reg stream_valid,stream_error,output reg [31:0] stream_data,
    output reg awvalid,output reg [31:0] awaddr,input wire awready,
    output reg wvalid,output reg [31:0] wdata,input wire wready,
    input wire bvalid,input wire [1:0] bresp,output wire bready,
    output reg arvalid,output reg [31:0] araddr,input wire arready,
    input wire rvalid,input wire [31:0] rdata,input wire [1:0] rresp,output wire rready
);
    localparam IDLE=0,WRITE=1,WRITE_RESPONSE=2,READ_ADDRESS=3,READ_RESPONSE=4;
    reg [2:0] state;
    reg stream_owner;
    assign host_ready=state==IDLE&&!stream_req;
    assign stream_ready=state==IDLE;
    assign bready=state==WRITE_RESPONSE;
    assign rready=state==READ_RESPONSE;
    function automatic allowed_command(input [5:0] cmd);
        case(cmd)
            0,2,3,6,7,8,9,13,16,17,41,55:allowed_command=1;
            default:allowed_command=0;
        endcase
    endfunction
    wire safe_write=(host_address==0 && (host_data&32'h0000ff30)==0) ||
        host_address==4 || (host_address==12 && allowed_command(host_data[29:24])) || host_address==16;
    always @(posedge clk)begin
        if(rst)begin
            state<=IDLE;stream_owner<=0;host_done<=0;host_error<=0;host_result<=0;
            stream_valid<=0;stream_error<=0;stream_data<=0;
            awvalid<=0;awaddr<=0;wvalid<=0;wdata<=0;arvalid<=0;araddr<=0;
        end else begin
            host_done<=0;stream_valid<=0;
            case(state)
                IDLE:begin
                    if(stream_req)begin
                        stream_owner<=1;araddr<=32'h2c;arvalid<=1;state<=READ_ADDRESS;
                    end else if(host_valid)begin
                        stream_owner<=0;host_error<=0;
                        if(host_address[1:0]!=0 || host_address>8'h30 || (host_write&&!safe_write))begin
                            host_done<=1;host_error<=1;
                        end else if(host_write)begin
                            awaddr<={24'd0,host_address};wdata<=host_data;awvalid<=1;wvalid<=1;state<=WRITE;
                        end else begin araddr<={24'd0,host_address};arvalid<=1;state<=READ_ADDRESS;end
                    end
                end
                WRITE:begin
                    if(awvalid&&awready)awvalid<=0;
                    if(wvalid&&wready)wvalid<=0;
                    if((!awvalid||awready)&&(!wvalid||wready))state<=WRITE_RESPONSE;
                end
                WRITE_RESPONSE:if(bvalid)begin host_done<=1;host_error<=bresp!=0;state<=IDLE;end
                READ_ADDRESS:if(arready)begin arvalid<=0;state<=READ_RESPONSE;end
                READ_RESPONSE:if(rvalid)begin
                    if(stream_owner)begin stream_data<=rdata;stream_error<=rresp!=0;stream_valid<=1;end
                    else begin host_result<=rdata;host_error<=rresp!=0;host_done<=1;end
                    state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
