# SDC template — cdc_sync_toggle (toggle-based event synchroniser)
#
# The only crossing is the toggle level toggle_q -> sync0_q (destination 2-FF
# chain). False-path it; the edge-detect flops are synchronous to DSTCK.
set INST  "<u_cdc_sync_toggle>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

set_false_path -to [get_pins ${INST}/sync0_q_reg/D]
set_false_path -to [get_pins ${INST}/*sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/sync0_q_reg ${INST}/sync1_q_reg ${INST}/sync2_q_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
