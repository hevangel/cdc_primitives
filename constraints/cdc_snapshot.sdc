# SDC template — cdc_snapshot (coherent multi-field snapshot)
#
# cdc_snapshot is a thin wrapper over cdc_bus_mcp (instance u_mcp): the whole
# vector crosses as one MCP transfer, so the constraints are the MCP ones
# applied to u_mcp.
set INST  "<u_cdc_snapshot>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"
set DSTPER "<dst_period_ns>"

set_false_path -to [get_pins ${INST}/u_mcp/tog_sync1_reg/D]
set_max_delay -datapath_only -from [get_cells ${INST}/u_mcp/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/u_mcp/d_data_reg[*]/D] $DSTPER
set_false_path -to [get_pins ${INST}/u_mcp/tog_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/u_mcp/tog_sync1_reg ${INST}/u_mcp/tog_sync2_reg ${INST}/u_mcp/tog_sync3_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
