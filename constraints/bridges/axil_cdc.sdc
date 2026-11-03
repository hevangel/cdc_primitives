# SDC template — axil_cdc (AXI4-Lite clock converter)
#
# Five async FIFOs, one per AXI channel:
#   u_aw, u_w, u_ar : slave clock  -> master clock   (SCK -> MCK)
#   u_b,  u_r       : master clock -> slave clock     (MCK -> SCK)
# Apply the cdc_async_fifo constraints to each. A helper proc keeps it short.
set INST "<u_axil_cdc>"
set SCK  "<s_axil_aclk>"
set MCK  "<m_axil_aclk>"
set SPER "<s_period_ns>"
set MPER "<m_period_ns>"

# fifo_cdc <fifo_inst> <wr_period> <rd_period>
proc fifo_cdc {F wper rper} {
    set_max_delay -datapath_only -from [get_cells ${F}/wgray_reg[*]] \
                                 -to   [get_pins  ${F}/wgray_rsync1_reg[*]/D] $rper
    set_max_delay -datapath_only -from [get_cells ${F}/rgray_reg[*]] \
                                 -to   [get_pins  ${F}/rgray_wsync1_reg[*]/D] $wper
    set_max_delay -datapath_only -from [get_cells ${F}/mem_reg[*]*] \
                                 -to   [get_pins  ${F}/rd_data*] $rper
    set_false_path -to [get_pins ${F}/*sync*_reg*/CLR]
}

# Slave -> master channels (write clock = SCK, read clock = MCK).
fifo_cdc ${INST}/u_aw $SPER $MPER
fifo_cdc ${INST}/u_w  $SPER $MPER
fifo_cdc ${INST}/u_ar $SPER $MPER
# Master -> slave channels (write clock = MCK, read clock = SCK).
fifo_cdc ${INST}/u_b  $MPER $SPER
fifo_cdc ${INST}/u_r  $MPER $SPER

# set_clock_groups -asynchronous -group [get_clocks $SCK] -group [get_clocks $MCK]
