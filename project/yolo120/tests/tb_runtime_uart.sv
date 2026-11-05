`timescale 1ns/1ps
module tb_runtime_uart;
    reg clk=0,reset=1,rx=1; always #4.15 clk=~clk;
    wire tx;
    vexii_ai_soc cpu(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
        .system_peripheral_uart_logic_uart_rxd(rx),.system_peripheral_uart_logic_uart_txd(tx),
        .system_peripheral_demo_logic_buttons(1'b0),.system_peripheral_demo_logic_leds(),
        .ai_awready(1'b1),.ai_wready(1'b1),.ai_arready(1'b1),
        .ai_bvalid(1'b0),.ai_rvalid(1'b0),.ai_bresp(2'b0),.ai_rresp(2'b0),.ai_rdata(32'b0));
    localparam BIT_CYCLES=1040;
    reg [7:0] requests[0:31],expected[0:31];
    integer received=0,i,j;
    reg [7:0] value;
    initial begin
        $readmemh("runtime_requests.hex",requests);
        $readmemh("runtime_replies.hex",expected);
        wait(!cpu.socCtrl_system_reset);
        forever begin
            @(negedge tx);
            repeat(BIT_CYCLES+BIT_CYCLES/2) @(posedge clk);
            for(j=0;j<8;j=j+1) begin
                value[j]=tx;repeat(BIT_CYCLES) @(posedge clk);
            end
            if(tx!==1'b1 || value!==expected[received])
                $fatal(1,"UART reply %0d got=%h expected=%h stop=%b",received,value,expected[received],tx);
            received=received+1;
            if(received==32) begin
                $display("RUNTIME_UART_PASS actual YOLO120 ELF boot, BSS, cmd10 A/B, UART reply CRC");
                $finish;
            end
        end
    end
    task send_byte(input [7:0] data);
        integer bit_index;
        begin
            @(negedge clk);rx=0;repeat(BIT_CYCLES) @(negedge clk);
            for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin
                rx=data[bit_index];repeat(BIT_CYCLES) @(negedge clk);
            end
            rx=1;repeat(BIT_CYCLES) @(negedge clk);
        end
    endtask
    initial begin
        repeat(160) @(negedge clk);reset=0;
        wait(!cpu.socCtrl_system_reset);repeat(50000) @(negedge clk);
        for(i=0;i<16;i=i+1) send_byte(requests[i]);
        wait(received==16);
        repeat(2*BIT_CYCLES) @(negedge clk);
        for(i=16;i<32;i=i+1) send_byte(requests[i]);
    end
    initial begin repeat(2000000) @(posedge clk);$fatal(1,"runtime UART timeout");end
endmodule
