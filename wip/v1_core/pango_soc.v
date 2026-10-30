// -----------------------------------------------------------------------------
// pango_soc.v -- V1 新核 SoC: CPU + 64KiB RAM + UART + GPIO + CLINT
//
// 地址映射 (与参考 MicroSoc.scala 一致):
//   0x8000_0000 + 64KiB : 主存 (取指/数据共用同一块 TDP RAM)
//   0x1000_0000         : CLINT (mtime / mtimecmp)  -> irq_timer
//   0x1000_1000         : UART  (0x00 数据, 0x04 状态, 0x08 分频, 0x0c 帧格式)
//   0x1000_3000         : GPIO / LED
//
// 取指与 Store 抢同一个 RAM 端口: store 优先, 取指这一拍不发起 (imem_ready=0),
// 对齐器下一拍自动重试。Load 走独立端口, 不受影响。
// -----------------------------------------------------------------------------
`include "core_config.vh"

module pango_soc (
    input  wire       clk,
    input  wire       rst,

    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [7:0] led,
    input  wire [0:0] btn
);
    // =========================================================================
    // CPU
    // =========================================================================
    wire [31:0] imem_addr, imem_rdata;
    wire        imem_req, imem_ready, imem_rvalid;

    wire [31:0] dmem_raddr, dmem_rdata;
    wire [31:0] dmem_waddr, dmem_wdata;
    wire [3:0]  dmem_be;
    wire        dmem_ren, dmem_wen;

    wire irq_timer;

    wire        commit_valid;
    wire [31:0] commit_pc, commit_instr;

    pango_cpu u_cpu (
        .clk          (clk),
        .rst          (rst),
        .imem_addr    (imem_addr),
        .imem_req     (imem_req),
        .imem_ready   (imem_ready),
        .imem_rdata   (imem_rdata),
        .imem_rvalid  (imem_rvalid),
        .dmem_raddr   (dmem_raddr),
        .dmem_ren     (dmem_ren),
        .dmem_rdata   (dmem_rdata),
        .dmem_waddr   (dmem_waddr),
        .dmem_wen     (dmem_wen),
        .dmem_be      (dmem_be),
        .dmem_wdata   (dmem_wdata),
        .dmem_ready   (1'b1),
        .dmem_err     (1'b0),
        .irq_timer    (irq_timer),
        .irq_ext      (1'b0),
        .irq_soft     (1'b0),
        .commit_valid (commit_valid),
        .commit_pc    (commit_pc),
        .commit_instr (commit_instr)
    );

    // =========================================================================
    // 主存: 端口 A = 取指读 / Store 写 ; 端口 B = Load 读
    // =========================================================================
    // 端口 A: Store 写优先, 空闲时给取指。取指若被抢, 由 imem_rvalid=0 告知对齐器,
    //        对齐器丢弃这笔数据并用同一块号重发 —— 这样 store 不必等, 取指也不会被污染。
    // 端口 B: 只给 Load 读。Load 与 Store 因此完全不冲突。
    wire [31:0] ram_rdata_a;
    wire [31:0] ram_rdata_b;

    // RAM 写使能必须按地址范围门控!
    // 少了这一条, MMIO 写 (UART/GPIO/CLINT) 会同时按 dmem_waddr[15:2] 截断后写进 RAM:
    // 实测 `MMIO(0x10003000)=1` 把 mem[0xC00] (指令 0x80003000) 覆盖成 1, 于是 pc 走到
    // 0x80003002 时取到非法指令。smoke 不写 GPIO, 所以没暴露; CoreMark 的 portable_init
    // 一开灯就中招。
    wire is_ram_w = (dmem_waddr[31:16] == 16'h8000);
    wire ram_wen      = dmem_wen & is_ram_w;
    wire port_a_fetch = ~ram_wen;
    reg  port_a_fetch_q;
    always @(posedge clk) port_a_fetch_q <= port_a_fetch;

    assign imem_ready  = 1'b1;
    assign imem_rvalid = port_a_fetch_q;
    assign imem_rdata  = ram_rdata_a;

    core_ram_tdp u_ram (
        .clk     (clk),
        .addr_a  (port_a_fetch ? imem_addr[15:2] : dmem_waddr[15:2]),
        .we_a    (ram_wen),
        .be_a    (dmem_be),
        .wdata_a (dmem_wdata),
        .rdata_a (ram_rdata_a),
        .addr_b  (dmem_raddr[15:2]),
        .rdata_b (ram_rdata_b)
    );

    // =========================================================================
    // MMIO
    // =========================================================================
    wire is_ram_r = (dmem_raddr[31:16] == 16'h8000);

    // ------------------------------ CLINT ------------------------------------
    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    assign irq_timer = (mtime >= mtimecmp);

    wire clint_w = dmem_wen & (dmem_waddr[31:12] == 20'h10000);

    // ------------------------------ UART -------------------------------------
    wire uart_sel_r = (dmem_raddr[31:12] == 20'h10001);
    wire uart_sel_w = (dmem_waddr[31:12] == 20'h10001);

    wire        u_tx_wr  = dmem_wen & uart_sel_w & (dmem_waddr[11:0] == 12'h000);
    wire [31:0] u_status;
    wire        u_txd;
    wire        u_div_wr = dmem_wen & uart_sel_w & (dmem_waddr[11:0] == 12'h008);
    wire        u_frm_wr = dmem_wen & uart_sel_w & (dmem_waddr[11:0] == 12'h00C);

    reg [19:0] u_div_q;
    reg [3:0]  u_frame_q;

    core_uart_tx u_uart (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (u_tx_wr),
        .wr_data (dmem_wdata[7:0]),
        .cfg_en  (u_div_wr),
        .cfg_div (dmem_wdata[19:0]),
        .status  (u_status),
        .txd     (u_txd)
    );

    assign uart_tx = u_txd;

    // ------------------------------ GPIO -------------------------------------
    wire gpio_sel_w = (dmem_waddr[31:12] == 20'h10003) & (dmem_waddr[11:0] == 12'h000);
    reg  [7:0] gpio_q;

    assign led = gpio_q;

    // ------------------------------ 读回多路 ---------------------------------
    reg [31:0] mmio_rdata;
    always @(*) begin
        case (dmem_raddr[31:12])
            20'h10001: mmio_rdata = (dmem_raddr[11:0] == 12'h004) ? u_status
                                   : (dmem_raddr[11:0] == 12'h008) ? {12'd0, u_div_q}
                                   : (dmem_raddr[11:0] == 12'h00C) ? {28'd0, u_frame_q}
                                   : 32'd0;
            20'h10003: mmio_rdata = {24'd0, gpio_q};
            20'h10000: begin
                case (dmem_raddr[11:0])
                    12'h000: mmio_rdata = mtime[31:0];
                    12'h004: mmio_rdata = mtime[63:32];
                    12'h008: mmio_rdata = mtimecmp[31:0];
                    12'h00C: mmio_rdata = mtimecmp[63:32];
                    default: mmio_rdata = 32'd0;
                endcase
            end
            default:   mmio_rdata = 32'd0;
        endcase
    end

    // MMIO 读响应比地址晚一拍 (与 CPU 的 EX 发地址 / MEM 收数据一致)
    reg [31:0] mmio_rdata_q;
    reg        mmio_r_q;
    always @(posedge clk) begin
        mmio_rdata_q <= mmio_rdata;
        mmio_r_q     <= ~is_ram_r & dmem_ren;
    end

    wire [31:0] dmem_rdata_mux = mmio_r_q ? mmio_rdata_q : ram_rdata_b;
    assign dmem_rdata = dmem_rdata_mux;

    // ------------------------------ 外设写 -----------------------------------
    always @(posedge clk) begin
        if (rst) begin
            mtime     <= 64'd0;
            mtimecmp  <= 64'hFFFF_FFFF_FFFF_FFFF;
            u_div_q   <= 20'd130;
            u_frame_q <= 4'h7;
            gpio_q    <= 8'd0;
        end else begin
            mtime <= mtime + 64'd1;
            if (clint_w) begin
                case (dmem_waddr[11:0])
                    12'h000: mtime[31:0]  <= dmem_wdata;
                    12'h004: mtime[63:32] <= dmem_wdata;
                    12'h008: mtimecmp[31:0]  <= dmem_wdata;
                    12'h00C: mtimecmp[63:32] <= dmem_wdata;
                    default: ;
                endcase
            end
            if (u_div_wr) u_div_q   <= dmem_wdata[19:0];
            if (u_frm_wr) u_frame_q <= dmem_wdata[3:0];
            if (gpio_sel_w) gpio_q  <= dmem_wdata[7:0];
        end
    end
endmodule
