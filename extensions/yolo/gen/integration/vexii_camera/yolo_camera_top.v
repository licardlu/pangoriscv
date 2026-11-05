`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-03-17  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
//cmos1、cmos2二选一，作为视频源输入
//`define CMOS_1      //cmos1作为视频输入；
`define CMOS_2      //cmos2作为视频输入；

module yolo_camera_top#(
	parameter MEM_ROW_ADDR_WIDTH   = 15         ,
	parameter MEM_COL_ADDR_WIDTH   = 10         ,
	parameter MEM_BADDR_WIDTH      = 3          ,
	parameter MEM_DQ_WIDTH         =  32        ,
	parameter MEM_DQS_WIDTH        =  32/8
)(
	input wire uart_rxd,
	input                                sys_clk              ,//50Mhz
    input                                clk_p ,
    input                                clk_n ,
//OV5640
    output  [1:0]                        cmos_init_done       ,//OV5640寄存器初始化完成
    //coms1	
    inout                                cmos1_scl            ,//cmos1 i2c 
    inout                                cmos1_sda            ,//cmos1 i2c 
    input                                cmos1_vsync          ,//cmos1 vsync
    input                                cmos1_href           ,//cmos1 hsync refrence,data valid
    input                                cmos1_pclk           ,//cmos1 pxiel clock
    input   [7:0]                        cmos1_data           ,//cmos1 data
    output                               cmos1_reset          ,//cmos1 reset
    //coms2
    inout                                cmos2_scl            ,//cmos2 i2c 
    inout                                cmos2_sda            ,//cmos2 i2c 
    input                                cmos2_vsync          ,//cmos2 vsync
    input                                cmos2_href           ,//cmos2 hsync refrence,data valid
    input                                cmos2_pclk           ,//cmos2 pxiel clock
    input   [7:0]                        cmos2_data           ,//cmos2 data
    output                               cmos2_reset          ,//cmos2 reset
//DDR
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_cs_n                  ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a                     ,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,
    output reg                           heart_beat_led            ,
    output                               ddr_init_done             ,
//MS72xx       
    output                               rstn_out                  ,
    output                               iic_tx_scl                ,
    inout                                iic_tx_sda                ,
    output                               hdmi_int_led              ,//HDMI_OUT初始化完成
    output                               uart_txd                  ,//CP210x UART TX on C24, 115200 8N1 telemetry
//HDMI_OUT
    output                               pix_clk                   ,//pixclk                           
    output     reg                       vs_out                    , 
    output     reg                       hs_out                    , 
    output     reg                       de_out                    ,
    output     reg[7:0]                  r_out                     , 
    output     reg[7:0]                  g_out                     , 
    output     reg[7:0]                  b_out         
);
/////////////////////////////////////////////////////////////////////////////////////
// ENABLE_DDR
    parameter CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;//28
    parameter TH_1S = 27'd33000000;
/////////////////////////////////////////////////////////////////////////////////////
    reg  [15:0]                 rstn_1ms            ;
    wire                        cmos_scl            ;//cmos i2c clock
    wire                        cmos_sda            ;//cmos i2c data
    wire                        cmos_vsync          ;//cmos vsync
    wire                        cmos_href           ;//cmos hsync refrence,data valid
    wire                        cmos_pclk           ;//cmos pxiel clock
    wire   [7:0]                cmos_data           ;//cmos data
    wire                        cmos_reset          ;//cmos reset
    wire                        initial_en          ;
    wire[15:0]                  cmos1_d_16bit       ;
    wire                        cmos1_href_16bit    ;
    reg [7:0]                   cmos1_d_d0          ;
    reg                         cmos1_href_d0       ;
    reg                         cmos1_vsync_d0      ;
    wire                        cmos1_pclk_16bit    ;
    wire[15:0]                  cmos2_d_16bit       /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_href_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    reg [7:0]                   cmos2_d_d0          /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_href_d0       /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_vsync_d0      /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_pclk_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire[15:0]                  o_rgb565            ;
    wire                        pclk_in_test        ;    
    wire                        vs_in_test          ;
    wire                        de_in_test          ;
    wire[15:0]                  i_rgb565   /*synthesis PAP_MARK_DEBUG="1"*/         ;
    wire                        de_re               ;
    wire [8:0]                  reg_idx1            ;
    wire [1:0]                  i2c_pins            ;
//axi bus   
    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;
    wire                        axi_awuser_ap              ;
    wire [3:0]                  axi_awuser_id              ;
    wire [3:0]                  axi_awlen                  ;
    wire                        axi_awready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_awvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;
    wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;
    wire                        axi_wready                 ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [3:0]                  axi_wusero_id              ;
    wire                        axi_wusero_last            ;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;
    wire                        axi_aruser_ap              ;
    wire [3:0]                  axi_aruser_id              ;
    wire [3:0]                  axi_arlen                  ;
    wire                        axi_arready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_arvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata                   /* synthesis syn_keep = 1 */;
    wire                        axi_rvalid                  /* synthesis syn_keep = 1 */;
    wire [3:0]                  axi_rid                    ;
    wire                        axi_rlast                  ;
    reg  [26:0]                 cnt                        ;
    reg  [15:0]                 cnt_1                      ;
/////////////////////////////////////////////////////////////////////////////////////
//PLL

    pll u_pll (
        .clkin1   (  sys_clk    ),//50MHz
        .clkout0  (  pix_clk    ),//37.125M 720P30
        .clkout1  (  cfg_clk    ),//10MHz
        .clkout2  (  clk_25M    ),//25M
        .lock (  locked     )
    );

//配置7210
wire init_over_tx;
    ms72xx_ctl ms72xx_ctl(
        .clk             (  cfg_clk        ), //input       clk,
        .rst_n           (  rstn_out       ), //input       rstn,
        .init_over    (  init_over_tx   ), //output      init_over,                                
        .init_over_rx    (  init_over_rx   ), //output      init_over,
//        .iic_tx_scl      (  iic_tx_scl     ), //output      iic_scl,
//        .iic_tx_sda      (  iic_tx_sda     ), //inout       iic_sda
        .iic_scl         (  iic_tx_scl        ), //output      iic_scl,
        .iic_sda         (  iic_tx_sda        )  //inout       iic_sda
    );
//   assign    hdmi_int_led    =    init_over_tx; 
    
    always @(posedge cfg_clk)
    begin
    	if(!locked)
    	    rstn_1ms <= 16'd0;
    	else
    	begin
    		if(rstn_1ms == 16'h2710)
    		    rstn_1ms <= rstn_1ms;
    		else
    		    rstn_1ms <= rstn_1ms + 1'b1;
    	end
    end
    
    assign rstn_out = (rstn_1ms == 16'h2710);

//配置CMOS///////////////////////////////////////////////////////////////////////////////////
//OV5640 register configure enable    
    power_on_delay	power_on_delay_inst(
    	.clk_50M                 (sys_clk        ),//input
    	.reset_n                 (1'b1           ),//input	
    	.camera1_rstn            (cmos1_reset    ),//output
    	.camera2_rstn            (cmos2_reset    ),//output	
    	.camera_pwnd             (               ),//output
    	.initial_en              (initial_en     ) //output		
    );
//CMOS1 Camera 
    reg_config	coms1_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos1_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos1_scl          ),//output
    	.i2c_sdat                (cmos1_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[0]  ),//output config_finished
    	.reg_index               (  reg_idx1         ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );

//CMOS2 Camera 
    reg_config	coms2_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos2_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos2_scl          ),//output
    	.i2c_sdat                (cmos2_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[1]  ),//output config_finished
    	.reg_index               (                   ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );
//CMOS 8bit转16bit///////////////////////////////////////////////////////////////////////////////////
//CMOS1
    always@(posedge cmos1_pclk)
        begin
            cmos1_d_d0        <= cmos1_data    ;
            cmos1_href_d0     <= cmos1_href    ;
            cmos1_vsync_d0    <= cmos1_vsync   ;
        end

    cmos_8_16bit cmos1_8_16bit(
    	.pclk           (cmos1_pclk       ),//input
    	.rst_n          (cmos_init_done[0]),//input
    	.pdata_i        (cmos1_d_d0       ),//input[7:0]
    	.de_i           (cmos1_href_d0    ),//input
    	.vs_i           (cmos1_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos1_pclk_16bit ),//output
    	.pdata_o        (cmos1_d_16bit    ),//output[15:0]
    	.de_o           (cmos1_href_16bit ) //output
    );
//CMOS2
    always@(posedge cmos2_pclk)
        begin
            cmos2_d_d0        <= cmos2_data    ;
            cmos2_href_d0     <= cmos2_href    ;
            cmos2_vsync_d0    <= cmos2_vsync   ;
        end

    cmos_8_16bit cmos2_8_16bit(
    	.pclk           (cmos2_pclk       ),//input
    	.rst_n          (cmos_init_done[1]),//input
    	.pdata_i        (cmos2_d_d0       ),//input[7:0]
    	.de_i           (cmos2_href_d0    ),//input
    	.vs_i           (cmos2_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos2_pclk_16bit ),//output
    	.pdata_o        (cmos2_d_16bit    ),//output[15:0]
    	.de_o           (cmos2_href_16bit ) //output
    );
//输入视频源选择//////////////////////////////////////////////////////////////////////////////////////////
// 自动选择：用 raw vsync 的下降沿判断哪个 sensor 真的在出流。没有 sensor 的通道 pclk 是死的，
// 计数器不会动，因此不会误选；也不依赖 SCCB 配置是否成功。
    reg  [3:0]  cam1_act, cam2_act;
    reg         cam1_vs_d, cam2_vs_d;
    always@(posedge cmos1_pclk)
    begin
        cam1_vs_d <= cmos1_vsync;
        if(cam1_vs_d && !cmos1_vsync && !(&cam1_act)) cam1_act <= cam1_act + 1'b1;
    end
    always@(posedge cmos2_pclk)
    begin
        cam2_vs_d <= cmos2_vsync;
        if(cam2_vs_d && !cmos2_vsync && !(&cam2_act)) cam2_act <= cam2_act + 1'b1;
    end

    wire        cam1_ok   = cam1_act[1];       // 收到 >=4 个场同步
    wire        cam2_ok   = cam2_act[1];
    wire        sel_cmos1 = 1'b1;
    wire [15:0] cam_d     = sel_cmos1 ? cmos1_d_16bit    : cmos2_d_16bit;
    wire        cam_de    = sel_cmos1 ? cmos1_href_16bit : cmos2_href_16bit;
    wire        cam_vs    = sel_cmos1 ? cmos1_vsync_d0   : cmos2_vsync_d0;

// The snapshot RAM spans clock regions; the DVP divider alone is regional.
GTP_CLKBUFG camera_pixel_global(.CLKIN(cmos1_pclk_16bit),.CLKOUT(pclk_in_test));
assign     vs_in_test      =    cam_vs     ;
assign     de_in_test      =    cam_de     ;
// DDR3 self-test pattern: an FPGA-generated image written into the frame buffer
// with the same write timing as the camera, then read back and displayed. If this
// shows clean, the DDR3 write/read geometry is correct and the fault is upstream
// in the camera capture. Undefine to go back to the real sensor.
//`define DDR_PATTERN_TEST 1
`ifdef DDR_PATTERN_TEST
    reg  [11:0] tp_x, tp_y;
    always @(posedge pclk_in_test)
    begin
        if (vs_in_test) begin
            tp_x <= 12'd0;
            tp_y <= 12'd0;
        end
        else if (de_in_test) begin
            if (tp_x == 12'd1279) begin
                tp_x <= 12'd0;
                tp_y <= (tp_y == 12'd719) ? 12'd0 : tp_y + 12'd1;
            end
            else
                tp_x <= tp_x + 12'd1;
        end
    end
    assign     i_rgb565        =    {tp_x[9:5],tp_y[8:4],tp_x[4:0]};
`else
    assign     i_rgb565        =    {cam_d[4:0],cam_d[10:5],cam_d[15:11]};//{r,g,b}
`endif
 assign    hdmi_int_led    = |i_rgb565;
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//修改ddr读写模块v1
    fram_buf fram_buf(
        .ddr_clk        (  core_clk             ),//input                         ddr_clk,
        .ddr_rstn       (  ddr_init_done        ),//input                         ddr_rstn,
        //data_in                                  
        .vin_clk        (  pclk_in_test         ),//input                         vin_clk,
        .wr_fsync       (  vs_in_test           ),//input                         wr_fsync,
        .wr_en          (  de_in_test           ),//input                         wr_en,
        .wr_data        (  i_rgb565             ),//input  [15 : 0]  wr_data,
        //data_out
        .vout_clk       (  pix_clk              ),//input                         vout_clk,
        .rd_fsync       (  vs_o               ),//input                         rd_fsync,
        .rd_en          (  de_re                ),//input                         rd_en,
        .vout_de        (  de_o               ),//output                        vout_de,
        .vout_data      (  o_rgb565             ),//output [PIX_WIDTH- 1'b1 : 0]  vout_data,
        .init_done      (  init_done            ),//output reg                    init_done,
        //axi bus
        .axi_awaddr     (  axi_awaddr           ),// output[27:0]
        .axi_awid       (  axi_awuser_id        ),// output[3:0]
        .axi_awlen      (  axi_awlen            ),// output[3:0]
        .axi_awsize     (                       ),// output[2:0]
        .axi_awburst    (                       ),// output[1:0]
        .axi_awready    (  axi_awready          ),// input
        .axi_awvalid    (  axi_awvalid          ),// output               
        .axi_wdata      (  axi_wdata            ),// output[255:0]
        .axi_wstrb      (  axi_wstrb            ),// output[31:0]
        .axi_wlast      (  axi_wusero_last      ),// input
        .axi_wvalid     (                       ),// output
        .axi_wready     (  axi_wready           ),// input
        .axi_bid        (  4'd0                 ),// input[3:0]
        .axi_araddr     (  axi_araddr           ),// output[27:0]
        .axi_arid       (  axi_aruser_id        ),// output[3:0]
        .axi_arlen      (  axi_arlen            ),// output[3:0]
        .axi_arsize     (                       ),// output[2:0]
        .axi_arburst    (                       ),// output[1:0]
        .axi_arvalid    (  axi_arvalid          ),// output
        .axi_arready    (  axi_arready          ),// input
        .axi_rready     (                       ),// output
        .axi_rdata      (  axi_rdata            ),// input[255:0]
        .axi_rvalid     (  axi_rvalid           ),// input
        .axi_rlast      (  axi_rlast            ),// input
        .axi_rid        (  axi_rid              ) // input[3:0]         
    );

//---- pixel data from frame buffer; 自诊断：无摄像头活动时窗口内显示彩条 ----
     wire [11:0] x_act_w;
     reg  [15:0] bar565;
     always@(*)
     begin
        case(x_act_w[10:7])
          4'd0 : bar565 = 16'hFFFF;
          4'd1 : bar565 = 16'hFFE0;
          4'd2 : bar565 = 16'h07FF;
          4'd3 : bar565 = 16'h07E0;
          4'd4 : bar565 = 16'hF81F;
          4'd5 : bar565 = 16'hF800;
          4'd6 : bar565 = 16'h001F;
          4'd7 : bar565 = 16'h0000;
          4'd8 : bar565 = 16'hFFFF;
          4'd9 : bar565 = 16'hFFE0;
          4'd10: bar565 = 16'h07FF;
          4'd11: bar565 = 16'h07E0;
          4'd12: bar565 = 16'hF81F;
          4'd13: bar565 = 16'hF800;
          4'd14: bar565 = 16'h001F;
          default: bar565 = 16'h0000;
        endcase
     end
     wire        cam_none = ~(cam1_ok | cam2_ok);
     wire [15:0] disp_px;
     wire [15:0] osd_px;

//---- display source: real DDR3 frame buffer (native 720p path) ----
     wire        cam_pclk_sel = sel_cmos1 ? cmos1_pclk : cmos2_pclk;
     reg  [11:0] wx, wy;
     wire [15:0] diag_px;

     assign disp_px = o_rgb565;

     always@(posedge pix_clk) begin
        if(!ddr_init_done) begin
            wx <= 12'd0;  wy <= 12'd0;
        end
        else if(vs_o) begin
            wx <= 12'd0;  wy <= 12'd0;
        end
        else if(de_re) begin
            if(wx == 12'd1279) begin
                wx <= 12'd0;
                wy <= (wy == 12'd719) ? 12'd0 : wy + 12'd1;
            end
            else
                wx <= wx + 12'd1;
        end
        else
            wx <= 12'd0;
     end

     wire [13:0] dbg_raddr;
     wire [15:0] dbg_rdata;
     wire [12:0] dbg_width, dbg_lines;

     assign i2c_pins = {cmos1_scl, cmos1_sda};

     cam_diag cam_diag_i(
        .cam_clk    (  cam_pclk_sel      ),
        .cam_rstn   (  ddr_init_done     ),
        .cam_vs     (  cam_vs            ),
        .cam_de     (  cam_de            ),
        .cam_d      (  cam_d             ),
        .disp_clk   (  pix_clk           ),
        .disp_rstn  (  ddr_init_done     ),
        .wx         (  wx                ),
        .wy         (  wy                ),
        .act1       (  cam1_act          ),
        .act2       (  cam2_act          ),
        .init_done  (  cmos_init_done    ),
        .raddr2     (  dbg_raddr         ),
        .rdata2     (  dbg_rdata         ),
        .dbg_width  (  dbg_width         ),
        .dbg_lines  (  dbg_lines         ),
        .px         (  diag_px           )
     );

     uart_cam_report #(
        .CLK_HZ  ( 24750000 ),
        .BAUD    ( 115200   )
     ) uart_cam_report_i (
        .clk      (  clk_25M        ),
        .rstn     (  locked         ),
        .width_v  (  dbg_width      ),
        .lines_v  (  dbg_lines      ),
        .act1     (  cam1_act       ),
        .act2     (  cam2_act       ),
        .sccb     (  cmos_init_done ),
        .sel      (  sel_cmos1      ),
        .reg_idx  (  reg_idx1       ),
        .pin_state(  i2c_pins       ),
        .raddr    (  dbg_raddr      ),
        .rdata    (  dbg_rdata      ),
        .txd      (                  ),
        .txd_b    (                  )
     );
     always@(posedge pix_clk) begin
        r_out<={osd_px[15:11],osd_px[15:13]};
        g_out<={osd_px[10:5],osd_px[10:9]};
        b_out<={osd_px[4:0],osd_px[4:2]};
        vs_out<=vs_o;
        hs_out<=hs_o;
        de_out<=de_o;
     end
/////////////////////////////////////////////////////////////////////////////////////
//产生visa时序 
     sync_vg sync_vg(                            
        .clk            (  pix_clk              ),//input                   clk,                                 
        .rstn           (  ddr_init_done            ),//input                   rstn,                            
        .vs_out         (  vs_o                 ),//output reg              vs_out,                                                                                                                                      
        .hs_out         (  hs_o                 ),//output reg              hs_out,            
        .de_out         (  de_re                     ),//output reg              de_out, 
        .de_re          (                  ),
        .x_act          (  x_act_w              ) //output reg [11:0]       x_act
    );  
////////////////////////////////////////////////////////////////////////////////////////////
//ddr    
/*        ddr3_100h ddr3_100h (
             .ref_clk                   (sys_clk            ),
             .resetn                    (rstn_out           ),// input
             .ddr_init_done             (ddr_init_done      ),// output
             .ddrphy_clkin              (core_clk           ),// output
             .pll_lock                  (pll_lock           ),// output

             .axi_awaddr                (axi_awaddr         ),// input [27:0]
             .axi_awuser_ap             (1'b0               ),// input
             .axi_awuser_id             (axi_awuser_id      ),// input [3:0]
             .axi_awlen                 (axi_awlen          ),// input [3:0]
             .axi_awready               (axi_awready        ),// output
             .axi_awvalid               (axi_awvalid        ),// input
             .axi_wdata                 (axi_wdata          ),
             .axi_wstrb                 (axi_wstrb          ),// input [31:0]
             .axi_wready                (axi_wready         ),// output
             .axi_wusero_id             (                   ),// output [3:0]
             .axi_wusero_last           (axi_wusero_last    ),// output
             .axi_araddr                (axi_araddr         ),// input [27:0]
             .axi_aruser_ap             (1'b0               ),// input
             .axi_aruser_id             (axi_aruser_id      ),// input [3:0]
             .axi_arlen                 (axi_arlen          ),// input [3:0]
             .axi_arready               (axi_arready        ),// output
             .axi_arvalid               (axi_arvalid        ),// input
             .axi_rdata                 (axi_rdata          ),// output [255:0]
             .axi_rid                   (axi_rid            ),// output [3:0]
             .axi_rlast                 (axi_rlast          ),// output
             .axi_rvalid                (axi_rvalid         ),// output

             .apb_clk                   (1'b0               ),// input
             .apb_rst_n                 (1'b1               ),// input
             .apb_sel                   (1'b0               ),// input
             .apb_enable                (1'b0               ),// input
             .apb_addr                  (8'b0               ),// input [7:0]
             .apb_write                 (1'b0               ),// input
             .apb_ready                 (                   ), // output
             .apb_wdata                 (16'b0              ),// input [15:0]
             .apb_rdata                 (                   ),// output [15:0]
             .apb_int                   (                   ),// output

             .mem_rst_n                 (mem_rst_n          ),// output
             .mem_ck                    (mem_ck             ),// output
             .mem_ck_n                  (mem_ck_n           ),// output
             .mem_cke                   (mem_cke            ),// output
             .mem_cs_n                  (mem_cs_n           ),// output
             .mem_ras_n                 (mem_ras_n          ),// output
             .mem_cas_n                 (mem_cas_n          ),// output
             .mem_we_n                  (mem_we_n           ),// output
             .mem_odt                   (mem_odt            ),// output
             .mem_a                     (mem_a              ),// output [14:0]
             .mem_ba                    (mem_ba             ),// output [2:0]
             .mem_dqs                   (mem_dqs            ),// inout [3:0]
             .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
             .mem_dq                    (mem_dq             ),// inout [31:0]
             .mem_dm                    (mem_dm             ),// output [3:0]
             //debug
             .debug_data                (                   ),// output [135:0]
             .debug_slice_state         (                   ),// output [51:0]
             .debug_calib_ctrl          (                   ),// output [21:0]
             .ck_dly_set_bin            (                   ),// output [7:0]
             .force_ck_dly_en           (1'b0               ),// input
             .force_ck_dly_set_bin      (8'h05              ),// input [7:0]
             .dll_step                  (                   ),// output [7:0]
             .dll_lock                  (                   ),// output
             .init_read_clk_ctrl        (2'b0               ),// input [1:0]
             .init_slip_step            (4'b0               ),// input [3:0]
             .force_read_clk_ctrl       (1'b0               ),// input
             .ddrphy_gate_update_en     (1'b0               ),// input
             .update_com_val_err_flag   (                   ),// output [3:0]
             .rd_fake_stop              (1'b0               ) // input
       );*/
wire clk_125Mhz ;

GTP_INBUFGDS #(
    .IOSTANDARD("DEFAULT"),
    .TERM_DIFF("ON")
) u_gtp (
    .O(clk_125Mhz), // OUTPUT  
    .I(clk_p), // INPUT  
    .IB(clk_n) // INPUT  
);
 reg [1:0] ddr_ref_rst;
wire ddr_resetn_ref;
ddr3_test u_ddr3_test_h(
             .ref_clk                   (clk_125Mhz            ),
             .resetn                    (ddr_resetn_ref           ),// input
             .ddr_init_done             (ddr_init_done      ),// output

             .pll_lock                  (pll_lock           ),// output

             .core_clk                  (core_clk),                                  // output

             .phy_pll_lock              (phy_pll_lock),                          // output
             .gpll_lock                 (gpll_lock),                                // output
             .rst_gpll_lock             (rst_gpll_lock),                        // output
             .ddrphy_cpd_lock           (ddrphy_cpd_lock),                    // output
             //.ddr_init_done             (ddr_init_done),                        // output


             .axi_awaddr                (native_awaddr),// input [27:0]
             .axi_awuser_ap             (1'b0               ),// input
             .axi_awuser_id             (native_awuser_id),// input [3:0]
             .axi_awlen                 (native_awlen),// input [3:0]
             .axi_awready               (native_awready),// output
             .axi_awvalid               (native_awvalid),// input
             .axi_wdata                 (native_wdata),
             .axi_wstrb                 (native_wstrb),// input [31:0]
             .axi_wready                (native_wready),// output
             .axi_wusero_id             (                   ),// output [3:0]
             .axi_wusero_last           (native_wusero_last),// output
             .axi_araddr                (native_araddr),// input [27:0]
             .axi_aruser_ap             (1'b0               ),// input
             .axi_aruser_id             (native_aruser_id),// input [3:0]
             .axi_arlen                 (native_arlen),// input [3:0]
             .axi_arready               (native_arready),// output
             .axi_arvalid               (native_arvalid),// input
             .axi_rdata                 (native_rdata),// output [255:0]
             .axi_rid                   (native_rid),// output [3:0]
             .axi_rlast                 (native_rlast),// output
             .axi_rvalid                (native_rvalid),// output

             .apb_clk                   (1'b0               ),// input
             .apb_rst_n                 (1'b1               ),// input
             .apb_sel                   (1'b0               ),// input
             .apb_enable                (1'b0               ),// input
             .apb_addr                  (8'b0               ),// input [7:0]
             .apb_write                 (1'b0               ),// input
             .apb_ready                 (                   ), // output
             .apb_wdata                 (16'b0              ),// input [15:0]
             .apb_rdata                 (                   ),// output [15:0]
//             .apb_int                   (                   ),// output

             .mem_rst_n                 (mem_rst_n          ),// output
             .mem_ck                    (mem_ck             ),// output
             .mem_ck_n                  (mem_ck_n           ),// output
             .mem_cke                   (mem_cke            ),// output
             .mem_cs_n                  (mem_cs_n           ),// output
             .mem_ras_n                 (mem_ras_n          ),// output
             .mem_cas_n                 (mem_cas_n          ),// output
             .mem_we_n                  (mem_we_n           ),// output
             .mem_odt                   (mem_odt            ),// output
             .mem_a                     (mem_a              ),// output [14:0]
             .mem_ba                    (mem_ba             ),// output [2:0]
             .mem_dqs                   (mem_dqs            ),// inout [3:0]
             .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
             .mem_dq                    (mem_dq             ),// inout [31:0]
             .mem_dm                    (mem_dm             ),// output [3:0]
             //debug

  .dbg_gate_start(1'b0),                      // input
  .dbg_cpd_start(1'b0),                        // input
  .dbg_ddrphy_rst_n(1'b1),                  // input
  .dbg_gpll_scan_rst(1'b0),                // input
  .samp_position_dyn_adj(1'b0),        // input
  .init_samp_position_even(32'd0),    // input [31:0]
  .init_samp_position_odd(32'd0),      // input [31:0]
  .wrcal_position_dyn_adj(1'b0),      // input
  .init_wrcal_position(32'd0),            // input [31:0]
  .force_read_clk_ctrl(1'b0),            // input
  .init_slip_step(16'd0),                      // input [15:0]
  .init_read_clk_ctrl(12'd0),              // input [11:0]
  .debug_calib_ctrl(),                  // output [33:0]
  .dbg_slice_status(),                  // output [67:0]
  .dbg_slice_state(),                    // output [87:0]
  .debug_data(),                              // output [275:0]
  .dbg_dll_upd_state(),                // output [1:0]
  .debug_gpll_dps_phase(),          // output [8:0]
  .dbg_rst_dps_state(),                // output [2:0]
  .dbg_tran_err_rst_cnt(),          // output [5:0]
  .dbg_ddrphy_init_fail(),          // output
  .debug_cpd_offset_adj(1'b0),          // input
  .debug_cpd_offset_dir(1'b0),          // input
  .debug_cpd_offset(10'd0),                  // input [9:0]
  .debug_dps_cnt_dir0(),              // output [9:0]
  .debug_dps_cnt_dir1(),              // output [9:0]
  .ck_dly_en(1'b0),                                // input
  .init_ck_dly_step(8'h0),                  // input [7:0]
  .ck_dly_set_bin(),                      // output [7:0]
  .align_error(),                            // output
  .debug_rst_state(),                    // output [3:0]
  .debug_cpd_state()                     // output [3:0]
       );
//心跳信号
     always@(posedge core_clk) begin
        if (!ddr_init_done)
            cnt <= 27'd0;
        else if ( cnt >= TH_1S )
            cnt <= 27'd0;
        else
            cnt <= cnt + 27'd1;
     end

     always @(posedge core_clk)
        begin
        if (!ddr_init_done)
            heart_beat_led <= 1'd1;
        else if ( cnt >= TH_1S )
            heart_beat_led <= ~heart_beat_led;
    end
                 
/////////////////////////////////////////////////////////////////////////////////////

    // Synchronize DDR reset release to the differential reference clock.
    // This removes the cfg_clk->DDR PHY recovery path while retaining
    // asynchronous assertion during PLL/reset loss.
    always @(posedge clk_125Mhz or negedge rstn_out)
        if(!rstn_out) ddr_ref_rst <= 2'b00;
        else ddr_ref_rst <= {ddr_ref_rst[0],1'b1};
    assign ddr_resetn_ref = ddr_ref_rst[1];

    // CPU/accelerator use the existing 27 MHz source for conservative bring-up.
    // Teammate CPU optimizations are not overwritten or assumed to meet 74 MHz.
    
    wire ai_clk,ai_pll_locked;
    ai_perf_pll ai_clock_pll(.clk(sys_clk),.rst_n(locked),
                            .core_clk(ai_clk),.locked(ai_pll_locked));

    wire ai_ready=locked && ai_pll_locked && ddr_init_done;
    reg [1:0] ai_reset=0,ddr_reset=0,cam_reset=0,pix_reset=0;
    always @(posedge ai_clk or negedge ai_ready)
        if(!ai_ready) ai_reset<=0;else ai_reset<={ai_reset[0],1'b1};
    always @(posedge core_clk or negedge ai_ready)
        if(!ai_ready) ddr_reset<=0;else ddr_reset<={ddr_reset[0],1'b1};
    always @(posedge pclk_in_test or negedge ai_ready)
        if(!ai_ready) cam_reset<=0;else cam_reset<={cam_reset[0],1'b1};
    always @(posedge pix_clk or negedge ai_ready)
        if(!ai_ready) pix_reset<=0;else pix_reset<={pix_reset[0],1'b1};
    wire vid_wr_en;
    wire [7:0] vid_wr_addr,vid_rd_addr;
    wire [31:0] vid_wr_data,vid_rd_data;
    wire [27:0] ai_awaddr,ai_araddr;
    wire [3:0] ai_awlen,ai_arlen;
    wire ai_awvalid,ai_awready,ai_wvalid,ai_wready,ai_wlast;
    wire ai_arvalid,ai_arready,ai_rvalid,ai_rlast,ai_rready;
    wire [255:0] ai_wdata,shared_rdata;
    wire [31:0] ai_wstrb;
    // 固件 ROM 初值：相对本文件指向同级的 vexii_firmware/program.hex。
    // 用 PDS 从别的目录编译时请改成本机绝对路径；重新运行
    // generate_vexii_camera.py 会自动写入当前机器的绝对路径。
    yolo_ai_client #(
        .PROGRAM_INIT_FILE("../../vexii_firmware/program.hex")
    ) ai(
        .clk_sys(ai_clk),.core_clk(core_clk),.rstn(ai_reset[1]),.ddr_rstn(ddr_reset[1]),
        .uart_rxd(uart_rxd),.uart_txd(uart_txd),
        .vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),.vid_wr_data(vid_wr_data),
        .vid_rd_addr(vid_rd_addr),.vid_rd_data(vid_rd_data),
        .d3_awaddr(ai_awaddr),.d3_awlen(ai_awlen),.d3_awvalid(ai_awvalid),
        .d3_awready(ai_awready),.d3_wdata(ai_wdata),.d3_wstrb(ai_wstrb),
        .d3_wvalid(ai_wvalid),.d3_wready(ai_wready),.d3_wusero_last(ai_wlast),
        .d3_araddr(ai_araddr),.d3_arlen(ai_arlen),.d3_arvalid(ai_arvalid),
        .d3_arready(ai_arready),.d3_rdata(shared_rdata),.d3_rvalid(ai_rvalid),
        .d3_rlast(ai_rlast),.d3_rready(ai_rready));
    video_ai_frontend #(.OSD_TEXT(1),.OSD_BORDER(4)) frontend(
        .cpu_clk(ai_clk),.cpu_rstn(ai_reset[1]),
        .wr_en(vid_wr_en),.wr_addr(vid_wr_addr),.wr_data(vid_wr_data),
        .rd_addr(vid_rd_addr),.rd_data(vid_rd_data),
        .cam_clk(pclk_in_test),.cam_rstn(cam_reset[1]),
        .cam_vs(vs_in_test),.cam_de(de_in_test),.cam_pixel(i_rgb565),
        .pix_clk(pix_clk),.pix_rstn(pix_reset[1]),.pix_vs(vs_o),.pix_de(de_o),
        .pix_in(disp_px),.pix_out(osd_px));
    wire [27:0] native_awaddr,native_araddr;
    wire [3:0] native_awlen,native_arlen,native_awuser_id,native_aruser_id,native_rid;
    wire native_awvalid,native_arvalid,native_awready,native_arready;
    wire [255:0] native_wdata,native_rdata;
    wire [31:0] native_wstrb;
    wire native_wready,native_wusero_last,native_rvalid,native_rlast;
    wire [1:0] arb_awready,arb_arready,arb_wready,arb_wlast,arb_rvalid,arb_rlast;
    wire [3:0] shared_rid;
    // Video ping-pong buffers occupy byte 0x08000000..0x09ffffff.
    // The unmodified video client otherwise collides with model byte 0x01000000.
    ddr_native_arbiter arbiter(
        .clk(core_clk),.rstn(ddr_reset[1]),
        .s_awaddr({ai_awaddr,axi_awaddr+28'h02000000}),
        .s_araddr({ai_araddr,axi_araddr+28'h02000000}),
        .s_awlen({ai_awlen,axi_awlen}),.s_arlen({ai_arlen,axi_arlen}),
        .s_awid({4'd1,axi_awuser_id}),.s_arid({4'd1,axi_aruser_id}),
        .s_awvalid({ai_awvalid,axi_awvalid}),.s_arvalid({ai_arvalid,axi_arvalid}),
        .s_awready(arb_awready),.s_arready(arb_arready),
        .s_wdata({ai_wdata,axi_wdata}),.s_wstrb({ai_wstrb,axi_wstrb}),
        .s_wready(arb_wready),.s_wlast(arb_wlast),
        .s_rdata(shared_rdata),.s_rid(shared_rid),
        .s_rvalid(arb_rvalid),.s_rlast(arb_rlast),
        .m_awaddr(native_awaddr),.m_awlen(native_awlen),.m_awid(native_awuser_id),
        .m_awvalid(native_awvalid),.m_awready(native_awready),
        .m_wdata(native_wdata),.m_wstrb(native_wstrb),.m_wready(native_wready),
        .m_wlast(native_wusero_last),
        .m_araddr(native_araddr),.m_arlen(native_arlen),.m_arid(native_aruser_id),
        .m_arvalid(native_arvalid),.m_arready(native_arready),
        .m_rdata(native_rdata),.m_rvalid(native_rvalid),.m_rlast(native_rlast),
        .m_rid(native_rid));
    assign {ai_awready,axi_awready}=arb_awready;
    assign {ai_arready,axi_arready}=arb_arready;
    assign {ai_wready,axi_wready}=arb_wready;
    assign {ai_wlast,axi_wusero_last}=arb_wlast;
    assign {ai_rvalid,axi_rvalid}=arb_rvalid;
    assign {ai_rlast,axi_rlast}=arb_rlast;
    assign axi_rdata=shared_rdata;
    assign axi_rid=shared_rid;

endmodule
