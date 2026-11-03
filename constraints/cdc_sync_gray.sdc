# SDC template — cdc_sync_gray (Gray-coded bus / counter synchroniser)
#
# The Gray word gray_q crosses into gray_sync1. Because the value is Gray-coded
# (only one bit changes per step) the bus is NOT false-pathed: it is bounded
# with a datapath-only max-delay so the whole word is captured within one
# destination period, preventing a stale/new bit mix beyond the guaranteed
# single-bit skew.
set INST  "<u_cdc_sync_gray>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

# One destination period (edit to your DSTCK period in ns).
set DSTPER "<dst_period_ns>"

set_max_delay -datapath_only -from [get_cells ${INST}/gray_q_reg[*]] \
                             -to   [get_pins  ${INST}/gray_sync1_reg[*]/D] $DSTPER
set_false_path -to [get_pins ${INST}/gray_sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/gray_sync1_reg[*] ${INST}/gray_sync2_reg[*]]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
