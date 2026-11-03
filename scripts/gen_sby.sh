#!/bin/sh
# Generate one SymbiYosys .sby per verifiable CDC primitive.
# Each .sby runs bmc / prove / cover tasks against the module's inline
# `ifdef FORMAL` SVA. Dependencies (submodules a primitive instantiates) are
# listed so Yosys elaborates the full hierarchy.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FORMAL="$HERE/formal"
mkdir -p "$FORMAL"

# module : space-separated rtl files (top first)
emit() {
    top=$1
    files=$2
    out="$FORMAL/$top.sby"
    {
        echo '[tasks]'
        echo 'bmc'
        echo 'prove'
        echo 'cover'
        echo
        echo '[options]'
        echo 'bmc: mode bmc'
        echo 'bmc: depth 20'
        echo 'prove: mode prove'
        echo 'prove: depth 20'
        echo 'cover: mode cover'
        echo 'cover: depth 40'
        echo
        echo '[engines]'
        echo 'bmc: abc bmc3'
        echo 'prove: abc pdr'
        echo 'cover: smtbmc --syn --nopresat z3'
        echo
        # FTOP guards environment ASSUMPTIONS so they only apply when this
        # module is the formal top — never when it is instantiated inside
        # another primitive (a leaked assume would constrain the parent).
        ftop=$(echo "$top" | tr '[:lower:]' '[:upper:]')_FTOP
        echo '[script]'
        printf 'read -formal -D FORMAL -D %s' "$ftop"
        # SBY copies [files] flat into src/ keyed by basename, so `read` names
        # each file by basename even when it lives in an rtl/ subdirectory.
        for f in $files; do printf ' %s' "$(basename "$f")"; done
        echo
        echo "prep -top $top"
        echo 'memory_map'
        echo
        echo '[files]'
        for f in $files; do echo "../rtl/$f"; done
    } > "$out"
    echo "wrote $out"
}

emit cdc_sync_bit            "cdc_sync_bit.sv"
emit cdc_sync_toggle         "cdc_sync_toggle.sv"
emit cdc_sync_pulse          "cdc_sync_pulse.sv cdc_sync_toggle.sv"
emit cdc_sync_event_handshake "cdc_sync_event_handshake.sv"
emit cdc_sync_sticky         "cdc_sync_sticky.sv"
emit cdc_sync_gray           "cdc_sync_gray.sv"
emit cdc_bus_handshake       "cdc_bus_handshake.sv"
emit cdc_bus_mcp             "cdc_bus_mcp.sv"
emit cdc_snapshot            "cdc_snapshot.sv cdc_bus_mcp.sv"
emit cdc_event_counter       "cdc_event_counter.sv cdc_sync_gray.sv"
emit cdc_async_fifo          "cdc_async_fifo.sv"
emit cdc_pingpong            "cdc_pingpong.sv cdc_bus_mcp.sv cdc_sync_toggle.sv"
emit cdc_mailbox             "cdc_mailbox.sv cdc_bus_handshake.sv"
emit rst_sync                "rst_sync.sv"
emit cdc_clock_stop_ctrl     "cdc_clock_stop_ctrl.sv"

# Protocol clock-converter bridges (built on the primitives above).
emit axis_cdc                "bridges/axis_cdc.sv cdc_async_fifo.sv"
emit apb_cdc                 "bridges/apb_cdc.sv cdc_bus_handshake.sv"
emit axil_cdc                "bridges/axil_cdc.sv cdc_async_fifo.sv"

echo 'all .sby files generated'
