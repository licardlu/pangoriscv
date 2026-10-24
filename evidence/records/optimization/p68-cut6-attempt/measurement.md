# p68 —— cut 6（D\$ 写地址打一拍）第一次真正实现：两条路都堵死

**日期**：2026-10-24 17:20–17:40　**结果**：**失败，已回退**（主干 RTL 未变）

## 做了什么

按 `docs/plan-v23-area-and-freq.md` §10.2 的正确做法（**不是** lesson 90 的老写法）：

1. 在 `dcache_axi.v` 里加 `dwr_q/dwr_idx/dwr_data/dwr_strb/dwr_set/dwr_word`
   （完全照抄同文件里 `lru_pend_q` 的成熟范式）；
2. `ST_IDLE` 接受 store 命中时只**锁存** `{idx, data, strb}`，阵列写挪到 always 块顶部
   由寄存器驱动 ⇒ 那根 fanout=256、2.500 ns 的地址网从 FF 出发；
3. 三条已有的 `ST_WR_*` 合并（711/731/747）保留（幂等，写同一份数据）；
4. 一拍互锁 `dwr_block`：下一拍的 cacheable read 若 `{set,word}` 相同，则拉低 `req_ready`。

## 两次仿真结果

| 变体 | 结果 |
|---|---|
| 带互锁 | `TEST_FAIL T_COREMARK_STALLED`，6,196 条退休后停在 PC `0x00000a60`（4.1 s） |
| 去掉互锁（只延迟写） | 跑到 4 亿拍上限，`ctrl = 396,859,544`，无 CRC ⇒ **彻底跑飞** |

修复尝试：把 `dwr_block` 里对 `req_valid` 的依赖去掉（怕 `req_ready`↔`req_valid` 组合环），
**仍然 stall** ⇒ 不是组合环，是语义问题。

## 学到什么（这条最重要）

1. **"store 之后紧一拍就有一条 load 命中同一 {set,word}"并不罕见**——去掉互锁后立刻跑飞，
   说明这个窗口在本 benchmark 里被大量命中。所以"延迟写 + 事后补偿"的做法必须有正确的旁路，
   而不能靠"应该很少见"。
2. **一拍互锁会把流水线卡死**：`req_ready` 这条握手在本设计里不是任意时刻都能拉低的
   （store 的 W 拍、posted queue 的 pop、`read_mem_now` 的排序规则都在同一个表达式里），
   在 ST_IDLE 以外拉低会出现**请求丢失**而不是停顿。
3. ⇒ 正确做法要么把互锁加到 LSU 侧（`req_valid` 保持到 `req_ready`，需要先证明 LSU 真的保持），
   要么做**真正的旁路**（11 位比较器 + 字节合并 mux），而后者会把逻辑加到本来就 4.89 ns 的读路径上。

## 结论

cut 6 的收益（4.77 ns）是真的，但它**不是一个"加几行"的改动**：它牵动
`req_ready` 握手、posted-queue 排序、以及 store→load 旁路三条语义。
在没有**硬件在环**（ILA/上板）可以抓波形定位的前提下，继续盲改缓存的风险高于收益。

**主干已回退**：`git diff 232dfa3 --stat -- firmware/code/rtl/` 为空（逐字节等于交付树）。
