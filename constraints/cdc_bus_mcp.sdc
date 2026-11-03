# SDC template — cdc_bus_mcp (multi-cycle-path data transfer)
#
# Textbook MCP: the data bus data_hold is held stable while a single load
# toggle crosses. The data path is a declared multi-cycle / max-delay path;
# the toggle crossing is false-pathed.
set INST  "<u_cdc_bus_mcp>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"
set DSTPER "<dst_period_ns>"

# Load-toggle control crossing.
set_false_path -to [get_pins ${INST}/tog_sync1_reg/D]

# Quasi-static data: bound to one destination period (the data has been stable
# for several cycles by the time it is captured).
set_max_delay -datapath_only -from [get_cells ${INST}/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/d_data_reg[*]/D] $DSTPER

set_false_path -to [get_pins ${INST}/tog_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/tog_sync1_reg ${INST}/tog_sync2_reg ${INST}/tog_sync3_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
