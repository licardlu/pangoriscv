`include "core_defs.vh"

module core_csr_file (
    input  wire        clk,
    input  wire        rst,

    // 读 (组合)
    input  wire [11:0] raddr,
    output reg  [31:0] rdata,
    output reg         csr_valid,
    output reg         csr_ro,          // 只读 CSR: 写它会触发非法指令

    // 写 (WB 级)
    input  wire        wr_en,
    input  wire [11:0] waddr,
    input  wire [31:0] wdata,

    // 写前递: 解决 "csrw mepc,t0 ; mret" 只隔一条指令时 mret 读到旧值的问题。
    // fwd0 来自 EX/MEM (更年轻), fwd1 来自 MEM/WB。
    input  wire        fwd0_we,
    input  wire [11:0] fwd0_addr,
    input  wire [31:0] fwd0_data,
    input  wire        fwd1_we,
    input  wire [11:0] fwd1_addr,
    input  wire [31:0] fwd1_data,

    // 陷入
    input  wire        trap_en,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_tval,
    input  wire [31:0] trap_epc,
    input  wire        mret_en,
    output wire [31:0] trap_vector,
    output wire [31:0] mepc_out,

    // 中断
    input  wire        irq_timer,
    input  wire        irq_ext,
    input  wire        irq_soft,
    output wire        mstatus_mie,
    output wire [31:0] mie_out,

    // 计数器
    input  wire        instret_en
);
    reg        mstatus_mie_q;
    reg        mstatus_mpie_q;
    reg [1:0]  mstatus_mpp_q;
    reg [31:0] mie_q;
    reg [31:0] mtvec_q;
    reg [31:0] mscratch_q;
    reg [31:0] mepc_q;
    reg [31:0] mcause_q;
    reg [31:0] mtval_q;
    reg [31:0] mcountinhibit_q;
    reg [63:0] mcycle_q;
    reg [63:0] minstret_q;

    wire [31:0] mip_val = {20'd0, irq_soft, 3'd0, irq_ext, 3'd0, irq_timer, 3'd0};

    assign mstatus_mie = mstatus_mie_q;
    assign mie_out     = mie_q;
    assign trap_vector = {mtvec_q[31:2], 2'b00};   // 只支持 direct 模式

    // mepc 读带前递: mret 在 EX 级读, 必须看到刚提交的 csrw mepc
    wire mepc_fwd1 = fwd1_we && (fwd1_addr == `CSR_MEPC);
    wire mepc_fwd0 = fwd0_we && (fwd0_addr == `CSR_MEPC);
    assign mepc_out = mepc_fwd0 ? fwd0_data
                    : mepc_fwd1 ? fwd1_data
                    :             mepc_q;

    // ------------------------------ 读端口 -----------------------------------
    always @(*) begin
        rdata     = 32'd0;
        csr_valid = 1'b1;
        csr_ro    = 1'b0;
        case (raddr)
            `CSR_MSTATUS:    rdata = {19'd0, mstatus_mpp_q, 3'd0, mstatus_mpie_q,
                                      3'd0, mstatus_mie_q, 3'd0};
            `CSR_MISA:       begin rdata = 32'h4000_1104; csr_ro = 1'b1; end // RV32 I M C
            `CSR_MIE:        rdata = mie_q;
            `CSR_MTVEC:      rdata = mtvec_q;
            `CSR_MSCRATCH:   rdata = mscratch_q;
            `CSR_MEPC:       rdata = mepc_q;
            `CSR_MCAUSE:     rdata = mcause_q;
            `CSR_MTVAL:      rdata = mtval_q;
            `CSR_MIP:        begin rdata = mip_val; csr_ro = 1'b1; end
            `CSR_MCOUNTINHIBIT: rdata = mcountinhibit_q;
            `CSR_MCYCLE:     rdata = mcycle_q[31:0];
            `CSR_MCYCLEH:    rdata = mcycle_q[63:32];
            `CSR_MINSTRET:   rdata = minstret_q[31:0];
            `CSR_MINSTRETH:  rdata = minstret_q[63:32];
            `CSR_MVENDORID,
            `CSR_MARCHID,
            `CSR_MIMPID,
            `CSR_MHARTID,
            `CSR_MCONFIGPTR: begin rdata = 32'd0; csr_ro = 1'b1; end
            default:         begin csr_valid = 1'b0; csr_ro = 1'b1; end
        endcase
        // 写前递覆盖 (更年轻的 exmem 优先)
        if (csr_valid) begin
            if (fwd1_we && (fwd1_addr == raddr)) rdata = fwd1_data;
            if (fwd0_we && (fwd0_addr == raddr)) rdata = fwd0_data;
        end
    end

    // ------------------------------ 写 + 陷入 --------------------------------
    always @(posedge clk) begin
        if (rst) begin
            mstatus_mie_q     <= 1'b0;
            mstatus_mpie_q    <= 1'b0;
            mstatus_mpp_q     <= 2'b00;
            mie_q             <= 32'd0;
            mtvec_q           <= 32'd0;
            mscratch_q        <= 32'd0;
            mepc_q            <= 32'd0;
            mcause_q          <= 32'd0;
            mtval_q           <= 32'd0;
            mcountinhibit_q   <= 32'd0;
            mcycle_q          <= 64'd0;
            minstret_q        <= 64'd0;
        end else begin
            // 计数器: mcycle 每拍 +1 (除非 inhibit), minstret 每条退休指令 +1
            if (!mcountinhibit_q[0]) mcycle_q <= mcycle_q + 64'd1;
            if (instret_en && !mcountinhibit_q[2]) minstret_q <= minstret_q + 64'd1;

            // WB 级 CSR 写 (较老指令)
            if (wr_en) begin
                case (waddr)
                    `CSR_MSTATUS: begin
                        mstatus_mie_q  <= wdata[`MSTATUS_MIE_BIT];
                        mstatus_mpie_q <= wdata[`MSTATUS_MPIE_BIT];
                        mstatus_mpp_q  <= wdata[`MSTATUS_MPP_LSB +: 2];
                    end
                    `CSR_MIE:        mie_q           <= wdata;
                    `CSR_MTVEC:      mtvec_q         <= {wdata[31:2], 2'b00};
                    `CSR_MSCRATCH:   mscratch_q      <= wdata;
                    `CSR_MEPC:       mepc_q          <= {wdata[31:1], 1'b0};
                    `CSR_MCAUSE:     mcause_q        <= wdata;
                    `CSR_MTVAL:      mtval_q         <= wdata;
                    `CSR_MCOUNTINHIBIT: mcountinhibit_q <= wdata;
                    `CSR_MCYCLE:     mcycle_q[31:0]  <= wdata;
                    `CSR_MCYCLEH:    mcycle_q[63:32] <= wdata;
                    `CSR_MINSTRET:   minstret_q[31:0]  <= wdata;
                    `CSR_MINSTRETH:  minstret_q[63:32] <= wdata;
                    default: ; // 只读/未实现地址: 在 EX 已判非法, 这里不再动作
                endcase
            end

            // mret: 恢复 MIE, 置 MPIE=1, MPP=U
            if (mret_en) begin
                mstatus_mie_q  <= mstatus_mpie_q;
                mstatus_mpie_q <= 1'b1;
                mstatus_mpp_q  <= 2'b00;
            end

            // trap: 最后发生, 优先级最高
            if (trap_en) begin
                mepc_q         <= {trap_epc[31:1], 1'b0};
                mcause_q       <= trap_cause;
                mtval_q        <= trap_tval;
                mstatus_mpie_q <= mstatus_mie_q;
                mstatus_mie_q  <= 1'b0;
                mstatus_mpp_q  <= 2'b11;
            end
        end
    end
endmodule
