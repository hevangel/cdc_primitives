#!/bin/sh
# Synthesise every CDC primitive with Yosys to confirm it is synthesisable
# (no initial blocks, delays, or other non-synthesisable constructs).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RTL="$HERE/rtl"
mkdir -p "$HERE/work/synth"

deps() {
    case "$1" in
        cdc_sync_pulse)     echo "cdc_sync_pulse.sv cdc_sync_toggle.sv" ;;
        cdc_snapshot)       echo "cdc_snapshot.sv cdc_bus_mcp.sv" ;;
        cdc_event_counter)  echo "cdc_event_counter.sv cdc_sync_gray.sv" ;;
        cdc_pingpong)       echo "cdc_pingpong.sv cdc_bus_mcp.sv cdc_sync_toggle.sv" ;;
        cdc_mailbox)        echo "cdc_mailbox.sv cdc_bus_handshake.sv" ;;
        *)                  echo "$1.sv" ;;
    esac
}

MODULES="cdc_sync_bit cdc_sync_toggle cdc_sync_pulse cdc_sync_event_handshake \
         cdc_sync_sticky cdc_sync_gray cdc_bus_handshake cdc_bus_mcp cdc_snapshot \
         cdc_event_counter cdc_async_fifo cdc_pingpong cdc_mailbox rst_sync \
         cdc_clock_stop_ctrl"

for m in $MODULES; do
    files=""
    for f in $(deps "$m"); do files="$RTL/$f $files"; done
    echo "synth $m"
    yosys -Q -l "$HERE/work/synth/$m.log" -p \
        "read_verilog -sv -I$RTL $files; synth -top $m -flatten; check; stat; write_json $HERE/work/synth/$m.json"
    grep -q 'Found and reported 0 problems' "$HERE/work/synth/$m.log"
done
echo 'CDC synthesis passed for all primitives'
