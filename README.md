# cdc_primitives

Clock domain crossing (CDC) primitives in SystemVerilog — a small, reusable,
**pre-verified** library that turns CDC from an ad-hoc signoff exercise into a
set of building blocks with explicit contracts, formal proofs, two-simulator
regressions, and synthesis checks.

The idea follows the "safe by construction" argument: instead of re-analysing
metastability for every crossing, a design uses an approved primitive for each
kind of transfer (level, event, coherent data word, stream, block, reset,
clock stop), and each primitive ships with a documented contract plus the
evidence that it meets it.

## The 15 foundational modules

Consolidated from the full 40-plus CDC taxonomy; variations and compositions
collapse onto one foundational module each.

| Module | Covers | Purpose |
|--------|--------|---------|
| `cdc_sync_bit` | A1, A2 | N-flop single-bit level synchroniser |
| `cdc_sync_toggle` | A3, A4 | Toggle-based event synchroniser |
| `cdc_sync_pulse` | A4, A5 | Pulse synchroniser with optional stretch |
| `cdc_sync_event_handshake` | A6 | Lossless event channel with backpressure |
| `cdc_sync_sticky` | A7, D4 | Sticky event / status flag |
| `cdc_sync_gray` | B1, D1 | Gray-coded monotonic bus / counter |
| `cdc_bus_handshake` | B2–B5 | Full req/ack multi-bit data transfer |
| `cdc_bus_mcp` | B6 | Multi-cycle-path data transfer |
| `cdc_snapshot` | B7, D2 | Coherent multi-field snapshot |
| `cdc_event_counter` | D3 | Lossless event-count transfer |
| `cdc_async_fifo` | C1–C3 | Dual-clock Gray-pointer async FIFO |
| `cdc_pingpong` | C4 | Double-buffer block transfer (w/ backpressure) |
| `cdc_mailbox` | C7 | One-deep lossless message mailbox |
| `rst_sync` | F1 | Async-assert / sync-deassert reset synchroniser |
| `cdc_clock_stop_ctrl` | G3, G4 | Clock stop/start handshake + output isolation |

`cdc_pkg.sv` provides shared Gray/binary helper functions for testbenches.

Protocol bridges (AXI/APB/AHB clock converters, E1–E8) are intentionally **out
of scope**: they are protocol wrappers built *on top of* these primitives, not
primitives themselves.

## Selecting a primitive

| Transferring… | Use |
|---------------|-----|
| Single-bit level | `cdc_sync_bit` |
| Single event / pulse | `cdc_sync_toggle` / `cdc_sync_pulse` |
| Event that must not be lost (backpressure) | `cdc_sync_event_handshake` |
| Sticky fault/status bit | `cdc_sync_sticky` |
| Monotonic multi-bit counter | `cdc_sync_gray` / `cdc_event_counter` |
| Arbitrary multi-bit word | `cdc_bus_handshake` / `cdc_bus_mcp` |
| Coherent group of fields | `cdc_snapshot` |
| Streaming data | `cdc_async_fifo` |
| Whole block | `cdc_pingpong` |
| Message / command | `cdc_mailbox` |
| Reset release | `rst_sync` |
| Clock stop / isolation | `cdc_clock_stop_ctrl` |

A CDC library cannot make an arbitrary crossing safe on its own: the designer
still has to classify the signal (level, event, coherent word, transaction,
stream). That classification picks the primitive.

## Contracts

Every module header documents its contract: **clock assumptions**, **data
assumptions**, **guarantees**, **reset behaviour**, and **physical
constraints** (ASYNC_REG on synchroniser flops, matched-skew Gray buses, SDC
timing exceptions on quasi-static / MCP paths). Read the header before
instantiating.

## Repository layout

```
rtl/        synthesisable SystemVerilog, one module per file
formal/     generated SymbiYosys .sby jobs (one per module)
tb/         two-clock self-checking simulation testbenches
scripts/    run_lint.sh, run_formal.sh, run_sim.sh, run_synth.sh, run_all.sh, gen_sby.sh
doc/        design notes
```

## Verification

Run the full flow inside the
[`ai-hw-engineer`](https://github.com/hevangel/ai_hw_engineer) Docker image
(Verilator 5.052, SymbiYosys 0.69 / Yosys 0.69, xezim):

```sh
docker run --rm -v "$(pwd):/cdc" ai-hw-engineer:latest sh -lc 'cd /cdc && sh scripts/run_all.sh'
```

What each stage checks:

- **Lint** — `verilator --lint-only -Wall` on every RTL module (strict) and
  every testbench (behavioural-idiom warnings waived).
- **Formal** — SymbiYosys `bmc`, `prove` (k-induction) and `cover` on each
  module's inline `` `ifdef FORMAL `` SVA. Data-integrity primitives use an
  `anyconst` payload oracle; environment assumptions are guarded by a
  per-module `*_FTOP` define so they never leak into a parent that instantiates
  the module. **45/45 formal checks pass.**
- **Simulation** — each module has a two-asynchronous-clock self-checking
  testbench run under **both** Verilator and xezim, asserting the primitive's
  guarantee (lossless/in-order/coherent/no-overflow/…) and printing a
  `CDC <module> PASS:` marker. **30/30 runs pass.**
- **Synthesis** — Yosys `synth` on every module confirms it is synthesisable
  (no initial blocks, delays, or other non-synthesisable constructs).

### Verified guarantees (highlights)

- `cdc_async_fifo`: FIFO ordering, no overflow, no underflow (occupancy proven
  `<= DEPTH`; Gray pointers proven to be the Gray encoding of their binary
  pointers).
- `cdc_bus_handshake` / `cdc_bus_mcp`: delivered data equals the source payload
  (proven with an `anyconst` oracle) — no multi-bit skew/corruption.
- `cdc_sync_event_handshake` / `cdc_mailbox`: lossless, in-order, one-in-flight
  with backpressure.
- `rst_sync`: reset asserts asynchronously, deasserts only synchronously.
- `cdc_clock_stop_ctrl`: the clock is never gated off without a confirmed
  grant, and outputs are isolated whenever the clock is off.

## Physical / STA notes

These RTL primitives still require correct constraints at implementation:

- Tag synchroniser flops with `ASYNC_REG` (already annotated in RTL) so the
  tool places them together for maximum MTBF.
- Constrain crossing paths with the appropriate SDC exception
  (`set_false_path` for pure synchronisers, `set_max_delay -datapath_only` /
  multicycle for MCP and Gray buses). A clean structural CDC report is **not**
  a substitute for correct constraints or for functional/protocol verification.

## License

Authored for the `ai_hw_engineer` project. See that repository for terms.
