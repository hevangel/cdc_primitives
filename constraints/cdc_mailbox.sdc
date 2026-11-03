# SDC template — cdc_mailbox (one-deep message mailbox)
#
# cdc_mailbox wraps cdc_bus_handshake (instance u_hs): apply the handshake
# constraints to u_hs.
set INST  "<u_cdc_mailbox>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"
set DSTPER "<dst_period_ns>"

set_false_path -to [get_pins ${INST}/u_hs/req_sync1_reg/D]
set_false_path -to [get_pins ${INST}/u_hs/ack_sync1_reg/D]
set_max_delay -datapath_only -from [get_cells ${INST}/u_hs/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/u_hs/d_data_reg[*]/D] $DSTPER
set_false_path -to [get_pins ${INST}/u_hs/*sync*_reg*/CLR]

# set_property ASYNC_REG true [get_cells ${INST}/u_hs/req_sync1_reg ${INST}/u_hs/req_sync2_reg ${INST}/u_hs/ack_sync1_reg ${INST}/u_hs/ack_sync2_reg]
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
