// Two-pixel-clock fallback UI; the decoded video keeps the same latency.
module media_display #(
    parameter FONT_FILE="media_font.hex",LABEL_FILE="media_labels.hex"
)(
    input wire clk,rst,input wire [1:0] page_async,input wire frame_start,
    input wire [3:0] ui_state_async,input wire has_frame_async,
    input wire [10:0] x,input wire [9:0] y,input wire [23:0] video_rgb,
    output reg page_active,output wire [23:0] rgb
);
    (* ASYNC_REG="TRUE" *)reg [1:0] page_meta,page_sync;
    (* ASYNC_REG="TRUE" *)reg [3:0] state_meta,state_sync;
    (* ASYNC_REG="TRUE" *)reg [1:0] frame_sync;
    reg [3:0] state;reg show_video;
    reg frame_old;reg [6:0] wave_phase;
    wire [10:0] wave_x=x-11'd448;
    wire [5:0] wave_angle=wave_phase[6:1]+{wave_x[8:5],2'b00};
    wire [5:0] wave_triangle=wave_angle[5]?6'd63-wave_angle:wave_angle;
    wire [9:0] wave_height=10'd8+{5'b0,wave_triangle[4:0]};
    (* syn_romstyle="block_rom" *)reg [15:0] font[0:2047];
    (* syn_romstyle="lut_rom" *)reg [7:0] labels[0:511];
    initial begin $readmemh(FONT_FILE,font);$readmemh(LABEL_FILE,labels);end
    reg [8:0] label_address;reg [3:0] fx,fy;reg text_on;
    reg [23:0] bg,fg;
    reg [10:0] dx;reg [9:0] dy;
    always @(*)begin
        label_address=0;fx=0;fy=0;text_on=0;dx=0;dy=0;
        bg=24'hf4f8fc;fg=24'h173952;
        if(x[4:0]==0||y[4:0]==0)bg=24'heaf1f7;
        if(x>=48&&x<1232&&y>=192&&y<592)begin
            bg=24'hffffff;
            if(x==48||x==1231||y==591)bg=24'hc9ddeb;
            if(y<196)bg=24'h19b7d7;
        end
        if(x>=24&&x<30&&y>=64&&y<96)bg=24'h19b7d7;
        if(y==624&&x>=48&&x<1232)bg=24'hc9ddeb;
        // Twelve procedural columns: no pixel/frame storage or multipliers.
        if(x>=448&&x<832&&wave_x[4:0]<14&&
           y>=10'd480-wave_height&&y<10'd480+wave_height)
            bg=wave_x[5]?24'h3cbd9c:24'h19b7d7;
        if(x>=64&&x<192&&y>=64&&y<96)begin
            dx=x-64;dy=y-64;label_address=dx>>5;fx=dx>>1;fy=dy>>1;text_on=1;
        end else if(x>=64&&x<384&&y>=112&&y<128)begin
            dx=x-64;dy=y-112;label_address=40+(dx>>4);fx=dx;fy=dy;text_on=1;fg=24'h197ca7;
        end else if(y>=320&&y<352&&x>=(state==3?544:512)&&x<(state==3?736:768))begin
            dx=x-(state==3?544:512);dy=y-320;label_address=(state==3?120:80)+(dx>>5);
            fx=dx>>1;fy=dy>>1;text_on=1;fg=state==3?24'hc86d29:24'h007fb5;
        end else if(y>=384&&y<400&&x>=(state==3?536:560)&&x<(state==3?744:720))begin
            dx=x-(state==3?536:560);dy=y-384;label_address=(state==3?200:160)+(dx>>4);
            fx=dx;fy=dy;text_on=1;
        end else if(y>=656&&y<672&&x>=64&&x<704)begin
            dx=x-64;dy=y-656;label_address=240+(dx>>4);fx=dx;fy=dy;text_on=1;
        end
    end
    wire [7:0] ch=labels[label_address];
    reg [15:0] glyph;reg [3:0] fx1;reg text1,ink2;
    reg [23:0] bg1,bg2,fg1,fg2;
    always @(posedge clk)begin
        glyph<=font[{ch[6:0],fy}];fx1<=fx;text1<=text_on;
        ink2<=text1&&glyph[15-fx1];bg1<=bg;bg2<=bg1;fg1<=fg;fg2<=fg1;
        if(rst)begin page_meta<=0;page_sync<=0;state_meta<=0;state_sync<=0;frame_sync<=0;page_active<=0;state<=0;show_video<=0;frame_old<=0;wave_phase<=0;end
        else begin
            frame_old<=frame_start;
            if(frame_start&&!frame_old&&page_sync==2)wave_phase<=wave_phase+1'b1;
            page_meta<=page_async;page_sync<=page_meta;
            state_meta<=ui_state_async;state_sync<=state_meta;
            frame_sync<={frame_sync[0],has_frame_async};
            if(frame_start)begin
                page_active<=page_sync==2;state<=state_sync;
                show_video<=state_sync==2&&frame_sync[1];
            end
        end
    end
    assign rgb=show_video?video_rgb:(ink2?fg2:bg2);
endmodule
