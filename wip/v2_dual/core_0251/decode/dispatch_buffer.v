// -----------------------------------------------------------------------------
// core_dispatch_buffer.v -- 取指/对齐结果缓冲 (4 项, 每拍可入 2 出 2)
//
// 参考设计里前端有两级缓冲 (aligner buffer + dispatch buffer)。本实现把两级
// 合并成这一级, 理由与差异登记在 docs/architecture/replica-differences.md (D-03):
//   - 对齐器已经按 pc 顺序产出, 再拆两级不改变任何可见时序合同;
//   - 合并后仍然是"寄存器输出 + 每拍最多 2 条"的同一语义。
//
// 为什么必须缓冲:
//   对齐器一拍能切 2 条, 但取指受 RAM 端口限制, 供给是不均匀的。没有缓冲时,
//   供给 1 条的那拍就只能发射 1 条, 原来能配对的指令被拆开, 双发射形同虚设。
//   缓冲让"供给抖动"和"发射宽度"解耦。
//
// 为什么是紧凑队列 (项永远排在 0..cnt-1):
//   读出端固定看 0/1 两项, 不需要读指针; 弹出时整体前移, 逻辑比环形指针直白。
//   代价是每项一个 4 选 1 的移位 mux —— 4x98 位, 可以接受。
// -----------------------------------------------------------------------------

module core_dispatch_buffer (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,

    // 入队 (来自对齐器, 0/1/2 条)
    input  wire [1:0]  push_n,
    input  wire [31:0] p0_pc,
    input  wire [31:0] p0_instr,
    input  wire [31:0] p0_raw,
    input  wire        p0_rvc,
    input  wire        p0_ill,
    input  wire [31:0] p1_pc,
    input  wire [31:0] p1_instr,
    input  wire [31:0] p1_raw,
    input  wire        p1_rvc,
    input  wire        p1_ill,

    output wire [2:0]  space,           // 剩余空间

    // 出队 (发射条数 0/1/2)
    input  wire [1:0]  pop_n,

    output wire [2:0]  count,
    output wire        q0_v,
    output wire [31:0] q0_pc,
    output wire [31:0] q0_instr,
    output wire [31:0] q0_raw,
    output wire        q0_rvc,
    output wire        q0_ill,
    output wire        q1_v,
    output wire [31:0] q1_pc,
    output wire [31:0] q1_instr,
    output wire [31:0] q1_raw,
    output wire        q1_rvc,
    output wire        q1_ill
);
    localparam EW = 98;                 // {pc, instr, raw, rvc, ill}

    reg [EW-1:0] q  [0:3];
    reg [EW-1:0] nq [0:3];
    reg [2:0]    cnt;

    wire [EW-1:0] e_p0 = {p0_pc, p0_instr, p0_raw, p0_rvc, p0_ill};
    wire [EW-1:0] e_p1 = {p1_pc, p1_instr, p1_raw, p1_rvc, p1_ill};

    assign space = 3'd4 - cnt;
    assign count = cnt;

    assign q0_v = (cnt >= 3'd1);
    assign q1_v = (cnt >= 3'd2);

    assign {q0_pc, q0_instr, q0_raw, q0_rvc, q0_ill} = q[0];
    assign {q1_pc, q1_instr, q1_raw, q1_rvc, q1_ill} = q[1];

    integer i;
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            if ((i + pop_n) < 4) nq[i] = q[i + pop_n];
            else                 nq[i] = {EW{1'b0}};
        end
        if (push_n >= 2'd1) nq[cnt - pop_n]       = e_p0;
        if (push_n == 2'd2) nq[cnt - pop_n + 3'd1] = e_p1;
    end

    always @(posedge clk) begin
        if (rst || flush) begin
            for (i = 0; i < 4; i = i + 1) q[i] <= {EW{1'b0}};
            cnt <= 3'd0;
        end else begin
            for (i = 0; i < 4; i = i + 1) q[i] <= nq[i];
            cnt <= cnt - pop_n + push_n;
        end
    end
endmodule
