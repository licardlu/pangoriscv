`timescale 1ns/1ps

// Standalone test stub. The production UI renderer is supplied by the parent
// display integration; this stub models its required two-cycle latency.
module ui_light_panel #(
    parameter BG="ui_light_bg.hex",
    parameter PAL="ui_light_palette.hex",
    parameter STATUS="ui_light_status.hex"
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [10:0] x,
    input  logic [9:0]  y,
    input  logic [127:0] snapshot,
    output logic [23:0] rgb
);
    logic [23:0] rgb_d;
    logic [127:0] snapshot_unused;
    always_ff @(posedge clk) begin
        snapshot_unused <= snapshot;
        if (rst) begin
            rgb_d <= 24'h0;
            rgb <= 24'h0;
        end else begin
            rgb_d <= {x[7:0], y[7:0], 8'h55};
            rgb <= rgb_d;
        end
    end
endmodule

module light_split_video_tb;
    logic clk=0;
    always #5 clk=~clk;
    logic rst=1;
    logic hs_in=0,vs_in=0,de_in=0;
    logic [15:0] pixel_in=0;
    logic [127:0] snapshot=128'h1234;
    logic hs_out,vs_out,de_out;
    logic [23:0] rgb_out;

    light_split_video dut(
        .clk(clk),.rst(rst),
        .hs_in(hs_in),.vs_in(vs_in),.de_in(de_in),.pixel_in(pixel_in),
        .snapshot(snapshot),
        .hs_out(hs_out),.vs_out(vs_out),.de_out(de_out),.rgb_out(rgb_out));

    function automatic [15:0] source565(input integer sx,input integer sy);
        source565={sx[9:5],sy[5:0],sx[4:0]};
    endfunction
    function automatic [23:0] expand565(input [15:0] p);
        expand565={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};
    endfunction

    integer tb_x,tb_y,frame_tag;
    logic q1_de,q2_de,q1_hs,q2_hs,q1_vs,q2_vs;
    integer q1_x,q2_x,q1_y,q2_y,q1_fid,q2_fid;
    integer row,col,frame;
    always @(posedge clk) begin
        if (rst) begin
            tb_x<=0;tb_y<=0;q1_x<=0;q2_x<=0;q1_y<=0;q2_y<=0;q1_fid<=0;q2_fid<=0;
            q1_de<=0;q2_de<=0;q1_hs<=0;q2_hs<=0;q1_vs<=0;q2_vs<=0;
        end else begin
            q1_de<=de_in;q2_de<=q1_de;
            q1_hs<=hs_in;q2_hs<=q1_hs;
            q1_vs<=vs_in;q2_vs<=q1_vs;
            q1_x<=tb_x;q2_x<=q1_x;q1_y<=tb_y;q2_y<=q1_y;
            q1_fid<=frame_tag;q2_fid<=q1_fid;
            if (vs_in) begin
                tb_x<=0;tb_y<=0;
            end else if (de_in) begin
                tb_x<=tb_x+1;
            end else if (q1_de && !de_in) begin
                tb_x<=0;tb_y<=tb_y+1;
            end
        end
    end

    always @(negedge clk) begin
        if (!rst) begin
            if (hs_out!==q2_hs || vs_out!==q2_vs || de_out!==q2_de)
                $fatal(1,"sync not delayed by exactly two cycles");
            if (de_out) begin
                if (q2_x<640) begin
                    if (rgb_out!=={q2_x[7:0],q2_y[7:0],8'h55})
                        $fatal(1,"left panel coordinate mismatch x=%0d y=%0d rgb=%h",q2_x,q2_y,rgb_out);
                end else begin
                    if (rgb_out!==expand565(source565(q2_x-320,q2_y+q2_fid)))
                        $fatal(1,"right crop mismatch output x=%0d source x=%0d y=%0d fid=%0d got=%h exp=%h",q2_x,q2_x-320,q2_y,q2_fid,rgb_out,expand565(source565(q2_x-320,q2_y+q2_fid)));
                end
            end else if (rgb_out!==24'h0) begin
                $fatal(1,"blanking must be black");
            end
        end
    end

    task automatic send_frame(input integer fid);
        begin
            frame_tag=fid;
            @(negedge clk);vs_in=1;de_in=0;hs_in=0;
            repeat(3) @(negedge clk);
            vs_in=0;
            for (row=0;row<3;row=row+1) begin
                for (col=0;col<1280;col=col+1) begin
                    @(negedge clk);de_in=1;hs_in=(col==0);
                    pixel_in=source565(col,row+fid);
                end
                @(negedge clk);de_in=0;hs_in=0;
                repeat(4) @(negedge clk);
            end
            @(negedge clk);vs_in=1;de_in=0;hs_in=0;
            repeat(2) @(negedge clk);vs_in=0;
        end
    endtask

    initial begin
        repeat(4) @(negedge clk);
        rst=0;
        send_frame(0);
        send_frame(1);
        $display("TEST_PASS light_split_video two-cycle sync + center crop + frame boundaries");
        $finish;
    end
    initial begin
        #300000;
        $fatal(1,"timeout");
    end
endmodule
