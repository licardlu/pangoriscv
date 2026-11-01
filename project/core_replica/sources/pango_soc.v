// -----------------------------------------------------------------------------
// pango_soc.v -- V2 新核 SoC: CPU + 64KiB RAM + UART + GPIO + CLINT
//
// 地址映射 (与参考 MicroSoc.scala 一致):
//   0x8000_0000 + 64KiB : 主存 (取指/数据共用同一块 TDP RAM)
//   0x1000_0000         : CLINT (mtime / mtimecmp)  -> irq_timer
//   0x1000_1000         : UART  (0x00 数据, 0x04 状态, 0x08 分频, 0x0c 帧格式)
//   0x1000_3000         : GPIO / LED
//
// 存储器组织: 8192 x 64 位。取指一拍读 8 字节 (够两条 32 位指令);
// Load 读 64 位字后按地址 bit[2] 选低/高半字; Store 按 bit[2] 放到对应半字。
//
// ★ 取指与 Store 抢同一个 A 口: store 优先, 这一拍用 imem_rvalid=0 告知对齐器,
//   对齐器丢弃该数据并按同一块号重发。不能改成"取指优先 + store 等待",
//   也不能让 store 无条件写 A 口而不通知取指 (V1 实测会把别的地址的数据当指令)。
//
// ★ RAM 写使能必须按地址范围门控: 少了这一条, MMIO 写会同时按 waddr[15:3]
//   截断写进 RAM, 把指令覆盖掉 (V1 实测 0x8000_3000 变成 1)。
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
    wire [31:0] imem_addr;
    wire [63:0] imem_rdata;
    wire        imem_req, imem_ready, imem_rvalid;

    wire [31:0] dmem_raddr, dmem_rdata;
    wire [31:0] dmem_waddr, dmem_wdata;
    wire [3:0]  dmem_be;
    wire        dmem_ren, dmem_wen;

    wire irq_timer;

    wire        commit_valid, commit_valid1;
    wire [31:0] commit_pc, commit_instr, commit_pc1, commit_instr1;
    wire [4:0]  commit_rd, commit_rd1;
    wire        commit_we, commit_we1;
    wire [31:0] commit_wdata, commit_wdata1;

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
        .dmem_ready   (dmem_ready),
        .dmem_err     (1'b0),
        .irq_timer    (irq_timer),
        .irq_ext      (1'b0),
        .irq_soft     (1'b0),
        .commit_valid (commit_valid),
        .commit_pc    (commit_pc),
        .commit_instr (commit_instr),
        .commit_rd    (commit_rd),
        .commit_we    (commit_we),
        .commit_wdata (commit_wdata),
        .commit_valid1(commit_valid1),
        .commit_pc1   (commit_pc1),
        .commit_instr1(commit_instr1),
        .commit_rd1   (commit_rd1),
        .commit_we1   (commit_we1),
        .commit_wdata1(commit_wdata1)
    );

    // =========================================================================
    // 主存: 端口 A = 取指读 / Store 写 ; 端口 B = Load 读
    // =========================================================================
    wire [63:0] ram_rdata_a;
    wire [63:0] ram_rdata_b;

    wire is_ram_w = (dmem_waddr[31:16] == 16'h8000);
    wire ram_wen  = dmem_wen & is_ram_w;

    // =========================================================================
    // Load 地址打一拍 (CFG_LOAD_ADDR_REG) -- 时序试验, 也是往参考结构靠
    //
    // 为什么要试: PDS run-006 的最差路径是
    //   idex_rs1q[0][4] -> 寄存器堆 32:1 mux -> ALU -> RAM ADA0
    // 12.773 ns (Route 7.921), 也就是"ALU 组合出地址后直接进 RAM 地址脚"。
    // 参考设计的访存地址是寄存后才给存储器的 (D$ 在下一级做 tag 比较)。
    //
    // 代价必须写清楚: 每条 Load 多花 1 拍 (用 dmem_ready 让 CPU 冻一拍来等
    // 寄存后的地址)。这不是免费的, 实测拍数见 docs/verification/v2-status.md。
    // 如果这条路径确实是瓶颈, 后续应该做的是"加一级访存流水 + Late ALU"
    // 把这个代价收回来 (P09), 而不是长期停在这个版本。
    //
    // 时序: 第 A 拍 ready=0 并锁存地址; 第 B 拍 ready=1, RAM 用锁存后的地址读,
    // 数据在第 C 拍出现在 dmem_rdata 上 (那时这条 Load 正好在 MEM 级)。
    // =========================================================================
`ifdef CFG_LOAD_ADDR_REG
    reg [31:0] ld_addr_q;
    reg        ld_busy;

    always @(posedge clk) begin
        if (rst) begin
            ld_addr_q <= 32'd0;
            ld_busy   <= 1'b0;
        end else if (dmem_ren && !ld_busy) begin
            ld_addr_q <= dmem_raddr;
            ld_busy   <= 1'b1;
        end else begin
            ld_busy   <= 1'b0;          // 放行那一拍之后复位, 下一条 Load 重新等
        end
    end

    assign dmem_ready = ld_busy ? 1'b1 : (dmem_ren ? 1'b0 : 1'b1);
    wire [31:0] ld_addr_ram = ld_addr_q;
`else
    assign dmem_ready = 1'b1;
    wire [31:0] ld_addr_ram = dmem_raddr;
`endif

    wire port_a_fetch = ~ram_wen;
    reg  port_a_fetch_q;
    always @(posedge clk) port_a_fetch_q <= port_a_fetch;

    assign imem_ready  = 1'b1;
    assign imem_rvalid = port_a_fetch_q;
    assign imem_rdata  = ram_rdata_a;

    // Store 数据与字节掩码放到 64 位字的正确半字
    wire [63:0] store_word = dmem_waddr[2] ? {dmem_wdata, 32'd0} : {32'd0, dmem_wdata};
    wire [7:0]  store_be   = {4'b0000, dmem_be} << (dmem_waddr[2] ? 4'd4 : 4'd0);

    core_ram_tdp u_ram (
        .clk     (clk),
        .addr_a  (port_a_fetch ? imem_addr[15:3] : dmem_waddr[15:3]),
        .we_a    (ram_wen),
        .be_a    (store_be),
        .wdata_a (store_word),
        .rdata_a (ram_rdata_a),
        .addr_b  (ld_addr_ram[15:3]),
        .rdata_b (ram_rdata_b)
    );

    // =========================================================================
    // MMIO
    // =========================================================================
    wire is_ram_r = (ld_addr_ram[31:16] == 16'h8000);

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
        case (ld_addr_ram[31:12])
            20'h10001: mmio_rdata = (ld_addr_ram[11:0] == 12'h004) ? u_status
                                   : (ld_addr_ram[11:0] == 12'h008) ? {12'd0, u_div_q}
                                   : (ld_addr_ram[11:0] == 12'h00C) ? {28'd0, u_frame_q}
                                   : 32'd0;
            20'h10003: mmio_rdata = {24'd0, gpio_q};
            20'h10000: begin
                case (ld_addr_ram[11:0])
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

    // MMIO 读响应比地址晚一拍, 与 CPU 的 "EX 发地址 / MEM 收数据" 对齐。
    // 只在 dmem_ren 那一拍采样: 若被多周期单元冻结, 必须保持住, 否则这条 Load
    // 会读到 RAM 的数据 (V1 的 printf 数字变 0 就是同一类丢数据问题)。
    reg [31:0] mmio_rdata_q;
    reg        mmio_r_q;
    reg        dmem_half_q;

    always @(posedge clk) begin
        if (dmem_ren) begin
            mmio_rdata_q <= mmio_rdata;
            mmio_r_q     <= ~is_ram_r;
            dmem_half_q  <= ld_addr_ram[2];
        end
    end

    wire [63:0] dmem_word = mmio_r_q ? {2{mmio_rdata_q}} : ram_rdata_b;
    assign dmem_rdata = dmem_half_q ? dmem_word[63:32] : dmem_word[31:0];

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
