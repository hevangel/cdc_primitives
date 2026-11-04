# SDC template — cdc_bus_handshake (req/ack multi-bit data transfer)
#
# The data bus data_hold is quasi-static: it is held stable by the source for
# the whole handshake, so only the req/ack control bits actually toggle across
# the boundary. Bound the data path (datapath-only max-delay) and false-path
# the single-bit control crossings.
set INST  "<u_cdc_bus_handshake>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"
set DSTPER "<dst_period_ns>"

# Control-bit crossings (no timing relationship).
set_false_path -to [get_pins ${INST}/req_sync1_reg/D]
set_false_path -to [get_pins ${INST}/ack_sync1_reg/D]

# Quasi-static data bus: bound so the destination samples one coherent value.
set_max_delay -datapath_only -from [get_cells ${INST}/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/d_data_reg[*]/D] $DSTPER

set_false_path -to [get_pins ${INST}/*sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/req_sync1_reg ${INST}/req_sync2_reg ${INST}/ack_sync1_reg ${INST}/ack_sync2_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
