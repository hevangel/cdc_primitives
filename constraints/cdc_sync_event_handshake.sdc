# SDC template — cdc_sync_event_handshake (4-phase req/ack event channel)
#
# Two single-bit level crossings:
#   source req_q  -> destination req_sync1   (SRCCK -> DSTCK)
#   dest   ack_level -> source  ack_sync1    (DSTCK -> SRCCK)
# Both are false paths; the synchroniser chains are otherwise synchronous.
set INST  "<u_cdc_sync_event_handshake>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

set_false_path -to [get_pins ${INST}/req_sync1_reg/D]
set_false_path -to [get_pins ${INST}/ack_sync1_reg/D]
set_false_path -to [get_pins ${INST}/req_sync*_reg*/CLR]
set_false_path -to [get_pins ${INST}/ack_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/req_sync1_reg ${INST}/req_sync2_reg ${INST}/ack_sync1_reg ${INST}/ack_sync2_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
