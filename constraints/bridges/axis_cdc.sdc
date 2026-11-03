# SDC template — axis_cdc (AXI-Stream clock converter)
#
# One async FIFO (instance u_fifo). Apply the cdc_async_fifo constraints to it.
set INST "<u_axis_cdc>"
set SCK  "<s_axis_aclk>"
set MCK  "<m_axis_aclk>"
set SPER "<s_period_ns>"
set MPER "<m_period_ns>"

set F ${INST}/u_fifo
set_max_delay -datapath_only -from [get_cells ${F}/wgray_reg[*]] \
                             -to   [get_pins  ${F}/wgray_rsync1_reg[*]/D] $MPER
set_max_delay -datapath_only -from [get_cells ${F}/rgray_reg[*]] \
                             -to   [get_pins  ${F}/rgray_wsync1_reg[*]/D] $SPER
set_max_delay -datapath_only -from [get_cells ${F}/mem_reg[*]*] \
                             -to   [get_pins  ${F}/rd_data*] $MPER
set_false_path -to [get_pins ${F}/*sync*_reg*/CLR]

# set_clock_groups -asynchronous -group [get_clocks $SCK] -group [get_clocks $MCK]
