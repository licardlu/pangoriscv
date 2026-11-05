`timescale 1ns/1ps
module tb_video_frontend;
    reg cpu_clk=0,pix_clk=0,cam_clk=0,cpu_rstn=0,pix_rstn=0,cam_rstn=0;
    always #5 cpu_clk=~cpu_clk;
    always #7 pix_clk=~pix_clk;
    always #9 cam_clk=~cam_clk;
    reg wr_en=0;
    reg [7:0] wr_addr=0,rd_addr=0;
    reg [31:0] wr_data=0;
    wire [31:0] rd_data;
    reg cam_vs=0,cam_de=0,pix_vs=0,pix_de=0;
    reg [15:0] cam_pixel=0,pix_in=16'h1234;
    wire [15:0] pix_out;
    video_ai_frontend #(.RESULT_TTL(2),.OSD_TEXT_SCALE(1)) dut(.*);
    wire [15:0] large_out;
    wire [31:0] large_rd;
    video_ai_frontend dut_large(
        .cpu_clk(cpu_clk),.cpu_rstn(cpu_rstn),.wr_en(wr_en),
        .wr_addr(wr_addr),.rd_addr(rd_addr),.wr_data(wr_data),.rd_data(large_rd),
        .cam_clk(cam_clk),.cam_rstn(cam_rstn),.cam_vs(cam_vs),.cam_de(cam_de),
        .cam_pixel(cam_pixel),.pix_clk(pix_clk),.pix_rstn(pix_rstn),
        .pix_vs(pix_vs),.pix_de(pix_de),.pix_in(pix_in),.pix_out(large_out));
    task wr(input [7:0] a,input [31:0] d);
        begin
            @(negedge cpu_clk);wr_en=1;wr_addr=a;wr_data=d;
            @(negedge cpu_clk);wr_en=0;
        end
    endtask
    task vs;
        begin
            @(negedge pix_clk);pix_vs=1;
            repeat(3) @(negedge pix_clk);
            pix_vs=0;
        end
    endtask
    function [15:0] expected_color;
        input integer class_id;
        begin
            case(class_id)
                0: expected_color=16'hfd20;
                1: expected_color=16'hffe0;
                2: expected_color=16'h07ff;
                3: expected_color=16'h001f;
                4: expected_color=16'hf81f;
                5: expected_color=16'h07e0;
                default: expected_color=16'h0000;
            endcase
        end
    endfunction
    function [7:0] expected_material_letter;
        input integer class_id,index;
        begin
            expected_material_letter=" ";
            case(class_id)
                0: case(index)
                    0:expected_material_letter="B";1:expected_material_letter="I";
                    2:expected_material_letter="O";3:expected_material_letter="D";
                    4:expected_material_letter="E";5:expected_material_letter="G";
                    default:expected_material_letter=" ";
                endcase
                1: case(index)
                    0:expected_material_letter="C";1:expected_material_letter="A";
                    2:expected_material_letter="R";3:expected_material_letter="D";
                    4:expected_material_letter="B";5:expected_material_letter="R";
                    6:expected_material_letter="D";default:expected_material_letter=" ";
                endcase
                2: case(index)
                    0:expected_material_letter="G";1:expected_material_letter="L";
                    2:expected_material_letter="A";3:expected_material_letter="S";
                    4:expected_material_letter="S";default:expected_material_letter=" ";
                endcase
                3: case(index)
                    0:expected_material_letter="M";1:expected_material_letter="E";
                    2:expected_material_letter="T";3:expected_material_letter="A";
                    4:expected_material_letter="L";default:expected_material_letter=" ";
                endcase
                4: case(index)
                    0:expected_material_letter="P";1:expected_material_letter="A";
                    2:expected_material_letter="P";3:expected_material_letter="E";
                    4:expected_material_letter="R";default:expected_material_letter=" ";
                endcase
                5: case(index)
                    0:expected_material_letter="P";1:expected_material_letter="L";
                    2:expected_material_letter="A";3:expected_material_letter="S";
                    4:expected_material_letter="T";5:expected_material_letter="I";
                    6:expected_material_letter="C";default:expected_material_letter=" ";
                endcase
                default:expected_material_letter=" ";
            endcase
        end
    endfunction
    function [7:0] expected_bin_letter;
        input integer class_id,index;
        begin
            expected_bin_letter=" ";
            if(class_id==0) begin
                case(index)
                    0:expected_bin_letter="K";1:expected_bin_letter="I";
                    2:expected_bin_letter="T";3:expected_bin_letter="C";
                    4:expected_bin_letter="H";5:expected_bin_letter="E";
                    6:expected_bin_letter="N";default:expected_bin_letter=" ";
                endcase
            end else begin
                case(index)
                    0:expected_bin_letter="R";1:expected_bin_letter="E";
                    2:expected_bin_letter="C";3:expected_bin_letter="Y";
                    4:expected_bin_letter="C";5:expected_bin_letter="L";
                    6:expected_bin_letter="E";default:expected_bin_letter=" ";
                endcase
            end
        end
    endfunction
    task check_labels;
        input integer class_id;
        integer n;
        reg [7:0] expected;
        begin
            for(n=0;n<8;n=n+1) begin
                expected=expected_material_letter(class_id,n);
                if(dut.letter(class_id,n)!==expected)
                    $fatal(1,"material label mismatch class=%0d char=%0d got=%h expected=%h",
                           class_id,n,dut.letter(class_id,n),expected);
                if(expected!=" " && dut.glyph(expected)==0)
                    $fatal(1,"material label uses missing glyph class=%0d char=%c",
                           class_id,expected);
                expected=expected_bin_letter(class_id,n);
                if(dut.bin_letter(class_id,n)!==expected)
                    $fatal(1,"bin label mismatch class=%0d char=%0d got=%h expected=%h",
                           class_id,n,dut.bin_letter(class_id,n),expected);
                if(expected!=" " && dut.glyph(expected)==0)
                    $fatal(1,"bin label uses missing glyph class=%0d char=%c",
                           class_id,expected);
            end
        end
    endtask
    task large_pixel(input integer px,py,input [15:0] expected);
        begin
            @(negedge pix_clk);
            pix_de=1;dut_large.x=px;dut_large.y=py;
            #1;
            if(large_out!==expected)
                $fatal(1,"large label pixel x=%0d y=%0d got=%h expected=%h",
                       px,py,large_out,expected);
            @(negedge pix_clk);pix_de=0;
        end
    endtask
    integer x,y,category,n;
    reg [34:0] expected_bits;
    reg [7:0] expected_char;
    reg [15:0] expected_pixel;
    initial begin
        repeat(4) @(negedge cpu_clk);cpu_rstn=1;pix_rstn=1;cam_rstn=1;
        for(category=0;category<6;category=category+1) check_labels(category);
        for(category=0;category<6;category=category+1) begin
            wr(8'h84,0);wr(8'h88,{16'd1,16'd2});
            wr(8'h8c,{16'd40,16'd71});
            wr(8'h90,32'h80000000|category);wr(8'h94,1);
            repeat(5) @(negedge pix_clk);
            if(category==0 && dut.box_class[0]!=0)
                $fatal(1,"OSD changed before frame boundary");
            vs();
            for(y=0;y<44;y=y+1) begin
                for(x=0;x<80;x=x+1) begin
                    @(negedge pix_clk);pix_de=1;
                    #1;
                    if(x>=2 && x<=71 && y>=1 && y<=40) begin
                        if((x<6 || x>67 || y<5 || y>36) &&
                           pix_out!=expected_color(category))
                            $fatal(1,"wrong class border color: class=%0d x=%0d y=%0d got=%h expected=%h",
                                   category,x,y,pix_out,expected_color(category));
                        if(x==6 && y==16 && pix_out!=pix_in)
                            $fatal(1,"border exceeded four pixels");
                        if(category==0 && x==7 && y==6 && pix_out!=16'hffff)
                            $fatal(1,"class label B must remain inside thick border");
                        if(category==0 && x==38 && y==6 && pix_out!=16'hffff)
                            $fatal(1,"BIODEG abbreviation must render through G");
                        if(category==1 && x==44 && y==6 && pix_out!=16'hffff)
                            $fatal(1,"CARDBRD abbreviation must render through D");
                        if(category==0 && x==7 && y==14 && pix_out!=16'hffff)
                            $fatal(1,"second row must render KITCHEN");
                        if(category==1 && x==7 && y==14 && pix_out!=16'hffff)
                            $fatal(1,"second row must render RECYCLE");
                    end else if(pix_out!=pix_in)
                        $fatal(1,"outside box changed");
                end
                @(negedge pix_clk);pix_de=0;
                repeat(2) @(negedge pix_clk);
            end
        end
        vs();vs();
        if(dut.age!=2) $fatal(1,"result TTL did not expire");
        @(negedge pix_clk);pix_de=1;
        #1;
        if(pix_out!=pix_in) $fatal(1,"expired result is still visible");
        pix_de=0;
        // Small target boxes must not suppress the independently sized label.
        for(category=0;category<6;category=category+1) begin
            wr(8'h84,0);wr(8'h88,{16'd1,16'd2});
            wr(8'h8c,{16'd30,16'd31});
            wr(8'h90,32'h80000000|category);wr(8'h94,1);
            repeat(5) @(negedge pix_clk);vs();
            for(y=0;y<64;y=y+1) for(x=0;x<192;x=x+1) begin
                n=(x/4)/6;
                expected_char=y<32 ? expected_material_letter(category,n) :
                    expected_bin_letter(category,n);
                expected_bits=dut.glyph(expected_char);
                expected_pixel=0;
                if((x/4)%6<5 && (y/4)%8<7 &&
                   expected_bits[34-((y/4)%8)*5-(x/4)%6])
                    expected_pixel=16'hffff;
                large_pixel(7+x,6+y,expected_pixel);
            end
        end
        for(n=0;n<300;n=n+1) vs();
        large_pixel(2,1,expected_color(5));
        // An empty inference clears old boxes on the next frame boundary.
        wr(8'h84,0);wr(8'h90,0);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);vs();
        large_pixel(7,6,pix_in);
        // Clamp the full label onto the screen for bottom/right-edge targets.
        wr(8'h88,{16'd710,16'd1270});wr(8'h8c,{16'd719,16'd1279});
        wr(8'h90,32'h80000000);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);vs();
        large_pixel(1088,656,16'hffff);
        large_pixel(1279,719,16'h0000);
        for(n=0;n<600;n=n+1) vs();
        large_pixel(1088,656,16'hffff);
        // Continuous mode keeps results until an explicit empty update.
        wr(8'h84,0);wr(8'h90,0);wr(8'h94,1);
        repeat(5) @(negedge pix_clk);vs();
        large_pixel(1088,656,pix_in);
        $display("VIDEO_FRONTEND_PASS six colors, 4px border, 4x labels, small/edge boxes, persistent result, empty clear");
        $finish;
    end
    initial begin repeat(500000) @(posedge cpu_clk);$fatal(1,"video timeout");end
endmodule
