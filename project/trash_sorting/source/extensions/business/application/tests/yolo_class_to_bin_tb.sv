`timescale 1ns/1ps
module yolo_class_to_bin_tb;
    reg result_valid=0;
    reg [7:0] result_class_id=0;
    wire bin_valid,custom_valid;
    wire [2:0] bin_code,custom_code;
    yolo_class_to_bin dut(.*);
    // Overrides make it possible to use a future, verified label policy;
    // they do not imply those labels are present in the current six-class model.
    yolo_class_to_bin #(.CLASS0_BIN(0),.CLASS1_BIN(2),.CLASS2_BIN(3)) custom(
        .result_valid(result_valid),.result_class_id(result_class_id),
        .bin_valid(custom_valid),.bin_code(custom_code));
    integer c;
    initial begin
        #1;
        if(bin_valid || bin_code!=0) $fatal(1,"invalid input created a bin");
        result_valid=1;
        for(c=0;c<6;c=c+1) begin
            result_class_id=c;#1;
            if(!bin_valid || bin_code!=(c==0?1:4))
                $fatal(1,"wrong default mapping for raw class %0d",c);
        end
        result_class_id=0;#1;
        if(custom_valid || custom_code!=0) $fatal(1,"disabled mapping accepted");
        result_class_id=1;#1;
        if(!custom_valid || custom_code!=2) $fatal(1,"red override failed");
        result_class_id=2;#1;
        if(!custom_valid || custom_code!=3) $fatal(1,"gray override failed");
        for(c=6;c<256;c=c+1) begin
            result_class_id=c;#1;
            if(bin_valid || bin_code!=0 || custom_valid || custom_code!=0)
                $fatal(1,"unsupported raw class was truncated: %0d",c);
        end
        result_valid=0;result_class_id=4;#1;
        if(bin_valid || bin_code!=0) $fatal(1,"empty result created a bin");
        $display("TEST_PASS yolo_class_to_bin six defaults + configurable overrides + invalid classes");
        $finish;
    end
endmodule
