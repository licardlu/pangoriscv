# CPU Memory Contract

Plan references: sections 3.5, 8.2, 9, 10.1 and 13.2.
Recorded 2026-10-10. This freezes the intended interfaces before T02;
it does not assert that these interfaces are integrated in the original CPU.
All interfaces share the CPU clock and active-low synchronous reset `rst_n`.
Payloads remain stable while valid is asserted and ready is low.
`fire = valid && ready` at the rising edge. Reset clears occupancy.

## Pipeline identity and retirement

IF/ID owns `valid`, `pc[31:0]`, `inst[31:0]`, `fault`,
`predicted_next_pc[31:0]`. ID/EX preserves these and decoded controls,
operands, `rd[4:0]` and CSR metadata. Stall holds identity and valid.
Flush clears younger valid slots and suppresses their internal handshakes.
An older EX branch may retire during its younger-slot flush.

EX owns one instruction until `ex_leave = retire_fire || trap_fire`.
`retire_fire` occurs once on normal completion; `trap_fire` accepts a
synchronous fault without normal retirement or rd writeback. Register/CSR
updates and branch training are tied to their defined commit event.
Monotonic `retire_order[63:0]` identifies retired instructions; PC is not
a unique identity. Decode samples operands only on entry to ID/EX, with
same-cycle completed EX writeback bypass or an explicit extra stall.

## Instruction operations

The IFU owns PC, redirect, request identity and a reserved result slot.
Its internal fetch request is `req_valid/req_ready`,
`req_pc[31:0]`, `req_predicted_next_pc[31:0]`.
The result is `rsp_valid/rsp_ready`, `rsp_pc[31:0]`, `rsp_inst[31:0]`,
`rsp_fault`, `rsp_predicted_next_pc[31:0]`. Fetch faults retain their
original PC; the trap cause is instruction access fault. Misaligned
targets are rejected before bus issue.

Identity begins at internal req_fire, before AR acceptance. Redirect
marks all younger identities stale, including requests accepted internally
on the redirect edge. An AXI VALID already asserted stays asserted until
handshake. Accepted stale reads drain to completion and are discarded.
Stale results never enter IF/ID or raise a wrong-path trap.
R reception uses the reserved slot independently of EX stalls, releasing
the shared bus before a waiting LSU request needs it.
Fetches to MMIO are rejected locally; no speculative peripheral read.

## Data operations

EX to LSU:

| Port | Width | Meaning |
| --- | --- | --- |
| op_valid / op_ready | 1 each | One operation handshake |
| is_store | 1 | Store versus load |
| address / store_value / pc | 32 each | Effective byte address, unshifted value, instruction PC |
| access_size | 3 | 0 byte, 1 halfword, 2 word; other values rejected |
| load_unsigned | 1 | Zero extension for byte/halfword loads |
| rd | 5 | Destination identity; x0 still performs the access |
| done_valid / done_ready | 1 each | Completion handshake |
| load_value / fault_addr | 32 each | Extended load result and original effective fault address |
| fault | 1 | Access failure; operation identity determines load/store cause |

LSU latches all request fields at op_fire. EX sets its issued bit only
on op_fire and never requests the same operation again while waiting.
done_valid and its payload are held until the corresponding retirement
or trap consumes them. A prechecked misalignment raises the synchronous
trap without issuing a memory request. Halfwords require address bit 0
zero; words require address bits 1:0 zero.

LSU alone shifts store_value by 8*address[1:0], generates WSTRB, selects
the load lane and performs sign/zero extension. Cache and bypass return
an unextended aligned 32-bit word; they do not extend it a second time.
A store completes after B, not after AW/W. BRESP errors produce one
store fault and are never automatically retried.

## Transfer engines and cache ownership

I-cache/D-cache own tag/data/LRU/refill only. They cannot retire CPU
instructions, update architectural PC or generate an independent trap.
T09 inserts cache logic behind the above operation interfaces.

Engine descriptors: `valid/ready`, `addr[31:0]`, `size[2:0]`,
`len[7:0]`, `id[3:0]`. Write beats use independent `valid/ready`,
`data[31:0]`, `strb[3:0]`, `last`. Read beats return independent
`valid/ready`, `data[31:0]`, `resp[1:0]`, `last`; descriptor ownership
preserves ID. Write completion holds `valid/ready`, `resp[1:0]`
until consumed. IF uses ID 0 and data uses ID 1 initially.

AXI exposes all five channels, 32-bit addresses/data, 4-bit IDs,
AxLEN/SIZE/BURST/LOCK/CACHE/PROT/QOS and RRESP/BRESP/LAST.
There is no WID. First release permits one global outstanding transfer,
INCR bursts up to 16 beats, no 4 KiB crossing, no exclusives.
AW and W are accepted independently; arbitration locks the owner before
either write channel can be accepted. All asserted channel payloads hold
through backpressure. Errors drain the promised beats and produce one
completion error. The verification model is not synthesizable CPU RTL.

## Interrupt, halt and maintenance boundaries

`arch_next_pc[31:0]` identifies the next unexecuted architectural
instruction. Interrupt acceptance is possible after retirement and when
EX is empty, even if a young fetch is waiting. Acceptance blocks young
entry to EX on that edge. A retiring branch sets the actual next target;
CSR/MRET state updates precede the interrupt eligibility check.
An already issued store drains and resolves before asynchronous interrupt.

halt_pending blocks younger work but lets current EX issue and finish
its one required LSU/divider request. Current exceptions/redirects
resolve first. No reset/halt leaves a live remote AXI transaction orphaned;
reset needs coordinated endpoint quiescence/reset.

FENCE.I must either implement the plan's complete store/fetch drain,
IF/ID/prefetch/I-cache/BTB/refill invalidation and PC+4 refetch sequence,
or decode as illegal and exclude Zifencei from the software ISA flags.
No partial maintenance implementation is accepted.
