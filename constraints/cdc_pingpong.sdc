# SDC template — cdc_pingpong (double-buffer block transfer)
#
# Crossings:
#   bank-select MCP (instance u_bank: cdc_bus_mcp WIDTH=1)   WCK -> RCK
#   done toggle    (instance u_done: cdc_sync_toggle)        RCK -> WCK
#   the two memory banks: written in WCK, read in RCK
set INST "<u_cdc_pingpong>"
set WCK  "<wr_clk>"
set RCK  "<rd_clk>"
set WPER "<wr_period_ns>"
set RPER "<rd_period_ns>"

# Bank-select MCP (1-bit data + toggle).
set_false_path -to [get_pins ${INST}/u_bank/tog_sync1_reg/D]
set_max_delay -datapath_only -from [get_cells ${INST}/u_bank/data_hold_reg*] \
                             -to   [get_pins  ${INST}/u_bank/d_data_reg*/D] $RPER

# Done-event toggle (read -> write domain).
set_false_path -to [get_pins ${INST}/u_done/sync0_q_reg/D]

# Memory banks: written in WCK, read combinationally in RCK.
set_max_delay -datapath_only -from [get_cells ${INST}/mem0_reg[*]* ${INST}/mem1_reg[*]*] \
                             -to   [get_pins  ${INST}/rd_data*] $RPER

set_false_path -to [get_pins ${INST}/u_bank/tog_sync*_reg*/CLR]
set_false_path -to [get_pins ${INST}/u_done/*sync*_reg*/CLR]

# set_clock_groups -asynchronous -group [get_clocks $WCK] -group [get_clocks $RCK]
