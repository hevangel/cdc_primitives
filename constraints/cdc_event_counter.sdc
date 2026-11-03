# SDC template — cdc_event_counter (lossless event-count transfer)
#
# A monotonic binary counter is Gray-crossed through an internal cdc_sync_gray
# (instance u_gray). Constrain the Gray word crossing with a datapath-only
# max-delay (same as cdc_sync_gray).
set INST  "<u_cdc_event_counter>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"
set DSTPER "<dst_period_ns>"

set_max_delay -datapath_only -from [get_cells ${INST}/u_gray/gray_q_reg[*]] \
                             -to   [get_pins  ${INST}/u_gray/gray_sync1_reg[*]/D] $DSTPER
set_false_path -to [get_pins ${INST}/u_gray/gray_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/u_gray/gray_sync1_reg[*] ${INST}/u_gray/gray_sync2_reg[*]]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
