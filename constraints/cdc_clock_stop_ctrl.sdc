# SDC template — cdc_clock_stop_ctrl (clock stop/start handshake + isolation)
#
# Crossings:
#   stop_req   ctrl -> target  (req_t1)       CTRLCK -> TGTCK
#   grant_q    target -> ctrl   (grant_c1)     TGTCK  -> CTRLCK
# Both are single-bit level crossings -> false path. The clock-gating enable
# clk_en is registered in the always-on ctrl domain (clean, no exception
# needed beyond treating the gated clock correctly in clock definitions).
set INST   "<u_cdc_clock_stop_ctrl>"
set CTRLCK "<ctrl_clk>"
set TGTCK  "<tgt_clk>"

set_false_path -to [get_pins ${INST}/req_t1_reg/D]
set_false_path -to [get_pins ${INST}/grant_c1_reg/D]
set_false_path -to [get_pins ${INST}/req_t*_reg*/CLR]
set_false_path -to [get_pins ${INST}/grant_c*_reg*/CLR]

# The target clock is produced by a clock-gating cell driven by clk_en. Define
# the gated clock on the gating-cell output and declare it asynchronous to the
# ctrl clock:
# create_generated_clock -name <tgt_clk_gated> -source [get_pins <icg>/CK] -divide_by 1 [get_pins <icg>/GCK]
# set_clock_groups -asynchronous -group [get_clocks $CTRLCK] -group [get_clocks $TGTCK]
