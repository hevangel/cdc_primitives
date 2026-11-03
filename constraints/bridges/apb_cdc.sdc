# SDC template — apb_cdc (APB clock bridge)
#
# Two req/ack handshakes:
#   u_req : request  (requester -> completer)   REQCK -> CMPCK
#   u_rsp : response (completer -> requester)   CMPCK -> REQCK
# Apply the cdc_bus_handshake constraints to each.
set INST  "<u_apb_cdc>"
set REQCK "<req_pclk>"
set CMPCK "<cmp_pclk>"
set REQPER "<req_period_ns>"
set CMPPER "<cmp_period_ns>"

# Request handshake (REQCK -> CMPCK).
set_false_path -to [get_pins ${INST}/u_req/req_sync1_reg/D]
set_false_path -to [get_pins ${INST}/u_req/ack_sync1_reg/D]
set_max_delay -datapath_only -from [get_cells ${INST}/u_req/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/u_req/d_data_reg[*]/D] $CMPPER

# Response handshake (CMPCK -> REQCK).
set_false_path -to [get_pins ${INST}/u_rsp/req_sync1_reg/D]
set_false_path -to [get_pins ${INST}/u_rsp/ack_sync1_reg/D]
set_max_delay -datapath_only -from [get_cells ${INST}/u_rsp/data_hold_reg[*]] \
                             -to   [get_pins  ${INST}/u_rsp/d_data_reg[*]/D] $REQPER

set_false_path -to [get_pins ${INST}/u_req/*sync*_reg*/CLR]
set_false_path -to [get_pins ${INST}/u_rsp/*sync*_reg*/CLR]

# set_clock_groups -asynchronous -group [get_clocks $REQCK] -group [get_clocks $CMPCK]
