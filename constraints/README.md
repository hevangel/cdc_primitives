# SDC constraint templates

One SDC template per primitive and per bridge. Each file is a **copy-and-fill**
template: replace the `<...>` placeholders (instance path, the two clock
objects) with the names from your design, then source it after your clocks are
created.

These constraints are what make a structurally-correct CDC primitive also
*timing*-correct: a clock-domain crossing has no meaningful setup/hold
relationship, so static timing analysis (STA) must be told to exclude or bound
each crossing path. Without them the tool either reports false violations or,
worse, tries to meet an impossible single-cycle path and the synchroniser's
MTBF assumption is silently broken.

## Exception types used

| Exception | When | Meaning |
|-----------|------|---------|
| `set_false_path` | pure level/control synchronisers, async resets | the path has no timing relationship; do not analyse it |
| `set_max_delay -datapath_only` | Gray buses, MCP/quasi-static data, FIFO memory read | bound the *data* propagation (so the captured value is coherent) but ignore the clock-edge relationship |
| `set_clock_groups -asynchronous` | between the two domain clocks | tell STA the clocks have no phase relationship |

`-datapath_only` (Synopsys) removes the clock-edge component of the max-delay
check and keeps only the combinational datapath — the correct form for a
quasi-static crossing. On Vivado the equivalent is `set_max_delay -datapath_only`
in XDC (same spelling); on tools without it, use a plain `set_max_delay` sized
to one destination period.

## General rules (apply to every instance)

1. Declare the two domain clocks and mark them mutually asynchronous **once**
   at the top level:
   ```tcl
   set_clock_groups -asynchronous -group {<clk_a>} -group {<clk_b>}
   ```
   The per-primitive files below assume this is already done and add the
   path-level exceptions that pin the specific crossing registers.
2. Keep synchroniser flops together: the RTL tags them `(* ASYNC_REG = "TRUE" *)`,
   which Vivado honours directly; for Synopsys flows add the equivalent
   `set_false_path`/placement attribute from this template.
3. A multi-bit crossing is only safe with a bounded skew — the
   `-datapath_only` max-delay is what bounds it. Size it to the **destination**
   clock period (one period is the usual, conservative choice).

## Files

| File | Module |
|------|--------|
| `cdc_sync_bit.sdc` | `cdc_sync_bit` |
| `cdc_sync_toggle.sdc` | `cdc_sync_toggle` |
| `cdc_sync_pulse.sdc` | `cdc_sync_pulse` |
| `cdc_sync_event_handshake.sdc` | `cdc_sync_event_handshake` |
| `cdc_sync_sticky.sdc` | `cdc_sync_sticky` |
| `cdc_sync_gray.sdc` | `cdc_sync_gray` |
| `cdc_bus_handshake.sdc` | `cdc_bus_handshake` |
| `cdc_bus_mcp.sdc` | `cdc_bus_mcp` |
| `cdc_snapshot.sdc` | `cdc_snapshot` |
| `cdc_event_counter.sdc` | `cdc_event_counter` |
| `cdc_async_fifo.sdc` | `cdc_async_fifo` |
| `cdc_pingpong.sdc` | `cdc_pingpong` |
| `cdc_mailbox.sdc` | `cdc_mailbox` |
| `rst_sync.sdc` | `rst_sync` |
| `cdc_clock_stop_ctrl.sdc` | `cdc_clock_stop_ctrl` |
| `bridges/axis_cdc.sdc` | `axis_cdc` |
| `bridges/apb_cdc.sdc` | `apb_cdc` |
| `bridges/axil_cdc.sdc` | `axil_cdc` |

Signal names in each file match the RTL (`sync_q`, `gray_q`, `data_hold`,
`wgray`/`rgray`, `mem`, …) so the register-filter patterns resolve against the
synthesised netlist.
