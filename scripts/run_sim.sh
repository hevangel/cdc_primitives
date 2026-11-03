#!/bin/sh
# Build and run every CDC testbench under Verilator and xezim, checking the
# per-module PASS marker in both logs.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RTL="$HERE/rtl"
mkdir -p "$HERE/work/sim"

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
    top="tb_$m"
    marker="CDC $m PASS:"
    files=""
    for f in $(deps "$m"); do files="$files $RTL/$f"; done

    echo "=== verilator sim: $top ==="
    verilator --binary --timing -Wall -Wno-TIMESCALEMOD -Wno-DECLFILENAME \
        -Wno-PROCASSINIT -Wno-SYNCASYNCNET -Wno-BLKSEQ \
        -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN -Wno-IMPLICITSTATIC \
        -I"$RTL" -j 4 \
        --top-module "$top" --Mdir "$HERE/work/sim/$top" \
        $files "$HERE/tb/$top.sv" > "$HERE/work/sim/$top-build.log" 2>&1
    "$HERE/work/sim/$top/V$top" > "$HERE/work/sim/$top-verilator.log" 2>&1
    grep "$marker" "$HERE/work/sim/$top-verilator.log"

    echo "=== xezim sim: $top ==="
    xezim --simulate --sv2017 --error-exit -I"$RTL" -s "$top" \
        $files "$HERE/tb/$top.sv" \
        --max-time 2000000ns -l "$HERE/work/sim/$top-xezim.log"
    grep "$marker" "$HERE/work/sim/$top-xezim.log"
done
echo 'CDC simulation passed for all primitives (Verilator + xezim)'
