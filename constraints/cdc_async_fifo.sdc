# SDC template — cdc_async_fifo (dual-clock Gray-pointer FIFO)
#
# Three crossings:
#   write Gray pointer wgray -> read domain  wgray_rsync1   (WCK -> RCK)
#   read  Gray pointer rgray -> write domain rgray_wsync1   (RCK -> WCK)
#   memory read: mem written in WCK, read combinationally in RCK
# Gray pointers are bounded (datapath-only); the memory read is bounded to one
# read period.
set INST  "<u_cdc_async_fifo>"
set WCK   "<wr_clk>"
set RCK   "<rd_clk>"
set WPER  "<wr_period_ns>"
set RPER  "<rd_period_ns>"

# Gray pointer crossings.
set_max_delay -datapath_only -from [get_cells ${INST}/wgray_reg[*]] \
                             -to   [get_pins  ${INST}/wgray_rsync1_reg[*]/D] $RPER
set_max_delay -datapath_only -from [get_cells ${INST}/rgray_reg[*]] \
                             -to   [get_pins  ${INST}/rgray_wsync1_reg[*]/D] $WPER

# Memory: written in the write domain, read asynchronously in the read domain.
# The FIFO guarantees a word is only read after its pointer has crossed, so
# bound (not false-path) the data to one read period.
set_max_delay -datapath_only -from [get_cells ${INST}/mem_reg[*]*] \
                             -to   [get_pins  ${INST}/rd_data*] $RPER

set_false_path -to [get_pins ${INST}/*sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/wgray_rsync1_reg[*] ${INST}/wgray_rsync2_reg[*] ${INST}/rgray_wsync1_reg[*] ${INST}/rgray_wsync2_reg[*]]
# set_clock_groups -asynchronous -group [get_clocks $WCK] -group [get_clocks $RCK]
