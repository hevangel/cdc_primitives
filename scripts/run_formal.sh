#!/bin/sh
# Run SymbiYosys (bmc + prove + cover) on every CDC primitive.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/gen_sby.sh" >/dev/null
MODULES="cdc_sync_bit cdc_sync_toggle cdc_sync_pulse cdc_sync_event_handshake \
         cdc_sync_sticky cdc_sync_gray cdc_bus_handshake cdc_bus_mcp cdc_snapshot \
         cdc_event_counter cdc_async_fifo cdc_pingpong cdc_mailbox rst_sync \
         cdc_clock_stop_ctrl axis_cdc apb_cdc axil_cdc"
TASKS=${1:-bmc prove cover}
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for m in $MODULES; do
    for t in $TASKS; do
        echo "formal $m $t"
        sby -f -d "$HERE/work/formal/${m}_${t}" "$m.sby" "$t"
    done
done
echo 'CDC formal (bmc+prove+cover) passed for all primitives'
