#!/bin/sh
# Lint every CDC primitive (RTL only) and every testbench with Verilator -Wall.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RTL="$HERE/rtl"

# top : dependency files (top first)
deps() {
    case "$1" in
        cdc_sync_pulse)     echo "cdc_sync_pulse.sv cdc_sync_toggle.sv" ;;
        cdc_snapshot)       echo "cdc_snapshot.sv cdc_bus_mcp.sv" ;;
        cdc_event_counter)  echo "cdc_event_counter.sv cdc_sync_gray.sv" ;;
        cdc_pingpong)       echo "cdc_pingpong.sv cdc_bus_mcp.sv cdc_sync_toggle.sv" ;;
        cdc_mailbox)        echo "cdc_mailbox.sv cdc_bus_handshake.sv" ;;
        axis_cdc)           echo "bridges/axis_cdc.sv cdc_async_fifo.sv" ;;
        apb_cdc)            echo "bridges/apb_cdc.sv cdc_bus_handshake.sv" ;;
        axil_cdc)           echo "bridges/axil_cdc.sv cdc_async_fifo.sv" ;;
        *)                  echo "$1.sv" ;;
    esac
}

MODULES="cdc_sync_bit cdc_sync_toggle cdc_sync_pulse cdc_sync_event_handshake \
         cdc_sync_sticky cdc_sync_gray cdc_bus_handshake cdc_bus_mcp cdc_snapshot \
         cdc_event_counter cdc_async_fifo cdc_pingpong cdc_mailbox rst_sync \
         cdc_clock_stop_ctrl axis_cdc apb_cdc axil_cdc"

for m in $MODULES; do
    files=""
    for f in $(deps "$m"); do files="$files $RTL/$f"; done
    echo "lint RTL: $m"
    verilator --lint-only -Wall -Wno-DECLFILENAME -I"$RTL" -I"$RTL/bridges" --top-module "$m" $files
done

# Testbenches (timing allowed). Behavioural-TB idioms are waived: initialised
# clock/counter variables (PROCASSINIT), blocking writes in always (BLKSEQ),
# and reference models that read reset both ways (SYNCASYNCNET) are expected
# in a testbench and are not RTL defects.
for m in $MODULES; do
    files=""
    for f in $(deps "$m"); do files="$files $RTL/$f"; done
    echo "lint TB: tb_$m"
    verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-TIMESCALEMOD --timing \
        -Wno-PROCASSINIT -Wno-SYNCASYNCNET -Wno-BLKSEQ \
        -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN -Wno-IMPLICITSTATIC \
        -Wno-UNUSEDSIGNAL \
        -I"$RTL" -I"$RTL/bridges" --top-module "tb_$m" $files "$HERE/tb/tb_$m.sv"
done
echo 'CDC lint passed'
