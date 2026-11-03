# SDC template — cdc_sync_pulse (pulse synchroniser with optional stretch)
#
# Wraps cdc_sync_toggle (instance u_tog) plus a destination-domain stretch
# counter. The only crossing is inside u_tog; the stretch counter is fully
# synchronous to DSTCK.
set INST  "<u_cdc_sync_pulse>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

set_false_path -to [get_pins ${INST}/u_tog/sync0_q_reg/D]
set_false_path -to [get_pins ${INST}/u_tog/*sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/u_tog/sync0_q_reg ${INST}/u_tog/sync1_q_reg ${INST}/u_tog/sync2_q_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
