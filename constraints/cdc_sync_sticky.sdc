# SDC template — cdc_sync_sticky (sticky status synchroniser)
#
# Two level crossings:
#   source sticky_q    -> dest   sts_sync1   (SRCCK -> DSTCK)
#   dest   d_clear_level -> source clr_sync1  (DSTCK -> SRCCK)
set INST  "<u_cdc_sync_sticky>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

set_false_path -to [get_pins ${INST}/sts_sync1_reg/D]
set_false_path -to [get_pins ${INST}/clr_sync1_reg/D]
set_false_path -to [get_pins ${INST}/sts_sync*_reg*/CLR]
set_false_path -to [get_pins ${INST}/clr_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/sts_sync1_reg ${INST}/sts_sync2_reg ${INST}/clr_sync1_reg ${INST}/clr_sync2_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
