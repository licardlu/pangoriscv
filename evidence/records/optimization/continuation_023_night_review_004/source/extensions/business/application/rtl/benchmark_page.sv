// White reference page. c0..c8 avoid the existing DDR bulk-register window.
module benchmark_page #(parameter FONT_FILE="benchmark_font.hex",parameter integer TRANSITION_ENABLE=0)(
    input wire cpu_clk,cpu_rst,page_async,wr_en,
    input tri0 start_toggle_async,
    input tri0 display_page_async,
    input tri0 audio_busy_async,
    input wire [7:0] wr_addr,rd_addr,input wire [31:0] wr_data,
    output reg [31:0] rd_data,output reg debug_page,
    input wire pix_clk,pix_rst,frame_start,input wire [10:0] x,input wire [9:0] y,
    output wire [23:0] rgb,output reg page_pix
);
    (* ASYNC_REG="TRUE" *) reg [1:0] page_sync,pix_page_sync,ack_sync,req_sync,start_sync,pixel_sync,audio_sync;
    reg start_old,pending,running,valid,req,ack,bank;
    reg [9:0] text_words;
    reg [9:0] cursor;
    reg [31:0] results[0:10];
    reg [31:0] text_ram[0:2047];
    reg [15:0] font_rom[0:4095];
    wire text_busy=req!=ack_sync[1];
    wire display_request=TRANSITION_ENABLE?display_page_async:page_async;
    integer i;
    initial begin
        // PDS limits a single elaboration loop to 2000 iterations.
        for(i=0;i<1024;i=i+1)begin text_ram[i]=0;text_ram[i+1024]=0;end
        if(FONT_FILE!="")$readmemh(FONT_FILE,font_rom);
    end
    always @(posedge cpu_clk)begin
        if(cpu_rst)begin
            page_sync<=0;start_old<=0;start_sync<=0;pixel_sync<=0;audio_sync<=0;
            pending<=0;running<=0;valid<=0;text_words<=0;
            debug_page<=0;cursor<=0;req<=0;ack_sync<=0;
            for(i=0;i<11;i=i+1)results[i]<=0;
        end else begin
            page_sync<={page_sync[0],page_async};start_sync<={start_sync[0],start_toggle_async};
            start_old<=start_sync[1];pixel_sync<={pixel_sync[0],page_pix};
            audio_sync<={audio_sync[0],audio_busy_async};
            ack_sync<={ack_sync[0],ack};
            // Consume late key CDC edges outside this page without queuing a
            // request that would silently start on the next manual page entry.
            if(start_sync[1]!=start_old&&page_sync[1]&&!running&&!pending)begin pending<=1;valid<=0;end
            if(page_sync==2'b10&&!running)pending<=0;
            if(wr_en)begin
                case(wr_addr)
                    8'hc0:begin cursor<=wr_data[9:0];text_words<=0;end
                    8'hc4:if(!text_busy)begin
                        text_ram[{~req,cursor}]<=wr_data;cursor<=cursor+1'b1;text_words<=text_words+1'b1;
                    end
                    8'hc8:if(wr_data[0]&&!text_busy)req<=!req;
                    8'hd0:begin
                        if(wr_data[0]&&pending&&!running)begin pending<=0;running<=1;valid<=0;end
                        if(wr_data[1]&&running)begin running<=0;valid<=1;end
                        if(wr_data[8])debug_page<=!debug_page;
                        if(wr_data[9]&&!pending&&!running)begin
                            pending<=1;valid<=0;
                            if(!page_sync[1])debug_page<=!debug_page;
                        end
                    end
                    default:if(wr_addr>=8'hd4)results[(wr_addr-8'hd4)>>2]<=wr_data;
                endcase
            end
        end
    end
    always @(*)begin
        rd_data=0;
        if(rd_addr==8'hd0)rd_data={25'b0,audio_sync[1],pixel_sync[1],text_busy,valid,page_sync[1],running,pending};
        else if(rd_addr==8'hcc)rd_data={22'b0,text_words};
        else if(rd_addr>=8'hd4)rd_data=results[(rd_addr-8'hd4)>>2];
    end
    // 80x44 cells; header/secondary scores use 2x and the primary score 3x.
    wire [10:0] metric_x=x-11'd80;
    wire [5:0] metric_y=y-10'd208;
    reg [6:0] col;
    reg [5:0] row;
    reg [3:0] fx,fy;
    reg [23:0] foreground;
    always @(*)begin
        col=x[10:4];row=y[9:4];fx=x[3:0];fy=y[3:0];
        foreground=24'h173952;
        if(x>=48&&x<960&&y>=32&&y<64)begin
            col=3+((x-48)>>5);row=2;fx=(x-48)>>1;fy=(y-32)>>1;
        end
        if(x>=80&&x<784&&y>=208&&y<256)begin
            col=7'd5+(metric_x/11'd48);row=14;fx=metric_x/11'd3;fy=metric_y/6'd3;
            foreground=24'h007fb5;
        end
        if(x>=848&&x<1200&&y>=192&&y<224)begin
            col=53+((x-848)>>5);row=12;fx=(x-848)>>1;fy=(y-192)>>1;
        end
        if(x>=848&&x<1200&&y>=320&&y<352)begin
            col=53+((x-848)>>5);row=20;fx=(x-848)>>1;fy=(y-320)>>1;
        end
        if(x>=1008&&x<1232&&y>=40&&y<80)foreground=24'h00876f;
        if(x>=48&&x<112&&y>=664&&y<696)foreground=24'hffffff;
    end
    wire [11:0] char_index=({6'b0,row}<<6)+({6'b0,row}<<4)+{5'b0,col};
    function automatic [23:0] backdrop(input [10:0] xx,input [9:0] yy);
        begin
            backdrop=24'hf4f8fc;
            if(xx[4:0]==0||yy[4:0]==0)backdrop=24'heaf1f7;
            if(xx>=48&&xx<784&&yy>=144&&yy<384)begin
                backdrop=24'hffffff;
                if(xx==48||xx==783||yy==383)backdrop=24'hc9ddeb;
                if(yy<148)backdrop=24'h19b7d7;
            end
            if(xx>=816&&xx<1232&&((yy>=144&&yy<256)||(yy>=272&&yy<384)))begin
                backdrop=24'hffffff;
                if(xx==816||xx==1231||yy==144||yy==255||yy==272||yy==383)backdrop=24'hc9ddeb;
                if(xx<820)backdrop=24'h197ca7;
            end
            if(xx>=48&&xx<1232&&yy>=416&&yy<640)begin
                backdrop=24'hffffff;
                if(xx==48||xx==1231||yy==416||yy==639)backdrop=24'hc9ddeb;
                if((yy==480||yy==528||yy==592)&&xx>=72&&xx<1208)backdrop=24'heaf1f7;
                if(xx==655&&yy>=432&&yy<584)backdrop=24'heaf1f7;
            end
            if(xx>=1008&&xx<1232&&yy>=40&&yy<80)backdrop=24'hddf5ef;
            if(xx>=24&&xx<30&&yy>=32&&yy<64)backdrop=24'h19b7d7;
            if(xx>=48&&xx<1232&&yy==656)backdrop=24'hc9ddeb;
            if(xx>=48&&xx<112&&yy>=664&&yy<696)backdrop=24'h147da5;
        end
    endfunction
    reg [31:0] text_word;
    reg [1:0] lane_d1;
    reg [3:0] fy_d1,fx_d1,fx_d2;
    reg [15:0] glyph;
    wire [7:0] character=(text_word>>(lane_d1*8));
    reg in_d1,in_d2;
    reg [23:0] bg_d1,bg_d2,fg_d1,fg_d2;
    (* ASYNC_REG="TRUE" *) reg [1:0] running_pix;
    reg [5:0] activity;
    reg frame_old;
    // Independent true dual-port RAM: one CPU writer, one pixel reader.
    always @(posedge pix_clk)begin
        text_word<=text_ram[{bank,char_index[11:2]}];
        lane_d1<=char_index[1:0];fy_d1<=fy;fx_d1<=fx;
        glyph<=font_rom[{character,fy_d1}];fx_d2<=fx_d1;
        in_d1<=x<1280&&y<704;in_d2<=in_d1;
        bg_d1<=running_pix[1]&&y>=608&&y<616&&x>=80&&x<1200 ?
            (((x[7:4]-activity[5:2])&4'hf)<4 ? 24'h19b7d7:24'heaf1f7):backdrop(x,y);
        bg_d2<=bg_d1;fg_d1<=foreground;fg_d2<=fg_d1;
        if(pix_rst)begin req_sync<=0;ack<=0;bank<=0;pix_page_sync<=0;page_pix<=0;
            running_pix<=0;activity<=0;frame_old<=0;end
        else begin
            req_sync<={req_sync[0],req};pix_page_sync<={pix_page_sync[0],display_request};
            running_pix<={running_pix[0],running};
            frame_old<=frame_start;
            if(frame_start&&!frame_old)begin
                activity<=activity+1'b1;
                page_pix<=pix_page_sync[1];
                if(req_sync[1]!=ack)begin bank<=req_sync[1];ack<=req_sync[1];end
            end
        end
    end
    assign rgb=in_d2&&glyph[15-fx_d2] ? fg_d2 : bg_d2;
endmodule
