# External Verification Handoff

Status: implementation in progress; this document is not a passing report.
User requested code-first work and delegated full verification to another AI.
Latest scope: BASIC VERSION ONLY. Cache, dynamic prediction, DDR, DMA and AI
are deferred. Items 13 and 15 below are future-plan references, not current
acceptance requirements; item 14 applies to the basic CPU.
Preserve the original backup and user changes. Do not modify RTL merely to
make a failing test pass without identifying the architectural cause.

## Environment

Workspace: `E:/file/pango/tinyriscv_axi4`.
Authoritative plan:
`E:/file/pango/docs/superpowers/plans/2026-10-09-tinyriscv-native-axi4-contest-plan.md`.
Results and implementation boundaries: `docs/implementation-status.md`.

```powershell
$python = 'C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:PATH = 'E:\donwload\win64;' + $env:PATH
& $python -m unittest discover -s sim -p test_baseline_runner.py -v
& $python sim/run_unit_tests.py --help
& $python sim/run_pipeline_tests.py --help
& $python sim/run_engine_tests.py --help
& $python sim/run_ifu_engine_tests.py --help
& $python sim/run_ram_tests.py --seeds 20
```

The CSR/interrupt integration changed the CPU trap ports. Older pipeline
benches must be updated to drive the three IRQ inputs and configure mtvec;
the legacy external `trap_vector` input no longer controls architectural
traps. Old unit pass logs predate this change and are not current CPU proof.

Use the documented command-line options from each runner. New runners must
be inspected before invocation; absence of a runner is an unmet deliverable,
not permission to invent a passing result. Use fresh simulation directories.
Require successful process exit, exactly one expected pass marker per case,
and no unexpected Error/Fatal/TIMEOUT. Expected-failure tests must fail for
their specific intended assertion, not an unrelated compile error.

## Verification Order

1. Compile only native sources in the native manifest. Reject legacy RIB,
   duplicate CPU/top definitions and reference modules in the native build.
   The isolated original 47-case baseline is a reference, not a native pass.
2. Pipeline: valid/ready holds, single retirement/writeback, x0, dependency
   bypass, divide stalls, branch/JALR redirects and young-fault flushing.
3. IFU: identity begins at internal request acceptance, redirects before AR
   and during R drain stale responses, held instruction/PC remain stable,
   latest redirected PC restarts autonomously in the full CPU.
4. LSU: every byte/halfword lane, signed/unsigned loads, WSTRB, alignment
   faults without bus traffic, delayed responses, store completion only at B,
   bus faults and trap backpressure without duplicate operations.
5. Engines: all five AXI channels, independent AW/W, stable VALID payloads,
   RID/BID/LAST checks, no retry after write error and fail-closed faults.
6. RAM: first/last/out-of-window addresses, high-bit aliases, synchronous
   reads, no reset clearing contents, independent AW/W, zero WSTRB,
   unsupported burst framing, malformed middle WLAST and LEN=255.
7. Interconnect: simultaneous IF/LSU requests, 20-cycle address stalls,
   round-robin progress, response ownership, W-first, AWREADY dependent on
   WVALID, unmapped DECERR bursts, second-beat SLVERR with ownership retained
   until the eighth beat, response stalls and coordinated reset.
8. Full CPU: actual arithmetic/branch/load-use/store programs, variable AXI
   latency, error paths, retirement trace against an architectural reference,
   halt with an unaccepted/accepted operation and correct resume PC.
9. Peripherals: exact register maps, byte masks, invalid offsets and read-only
   permissions; UART exactly one character and busy error; GPIO synchronized
   input; timer/IRQ new-event priority over simultaneous pending clear.
10. CSR/traps/interrupts: all required causes; encoded zero CSR masks;
    read-only writes; WARL mtvec/mepc/mstatus; atomic trap state; MRET;
    pending/mie/MIE priority; empty-EX interrupts and draining old stores.
11. Software: high-low-high cycle read, 64-bit wrap-safe delays, trap register
    preservation, correct interrupt source clearing, initialized stack/data,
    RV32I or RV32IM ELF with no compressed instructions anywhere.
12. CoreMark: unmodified benchmark algorithms, legitimate integer timing
    port, correct configuration/CRC, real clock and at least ten seconds.
    Compilation, simulation and board performance are separate evidence.
13. Cache/prediction only after their plan gates: both two-way caches,
    full refill/error draining, replacement/write policy, no MMIO caching,
    predictor commit/update/redirect tests and correct maintenance scope.
14. PDS: native CPU compile/synthesis/place-and-route, requested clock timing,
    resources and actual RAM mapping. LED example reports are not CPU proof.
15. Board/DDR/AI: actual hardware download, UART/GPIO/interrupt behavior,
    vendor DDR signal contract and CDC/reset, frozen model/weights/operators,
    DMA boundaries/errors and complete end-to-end output.

## Evidence Rules

Report each item as PASS, FAIL, NOT RUN or BLOCKED, with exact commands,
source revision, fresh log path, counts and failure details. Do not label
syntax checks as simulation, simulation as synthesis, or modeled
performance as board speedup. FENCE.I is currently intentionally illegal;
do not claim Zifencei support from the original reference test.

Full-plan completion requires physical-board and model/vendor inputs.
Missing inputs must be listed explicitly; placeholder RTL is not completion.
