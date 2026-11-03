# SDC template — rst_sync (async-assert / sync-deassert reset synchroniser)
#
# raw_rst_n asserts the chain asynchronously; the deassertion is synchronous to
# dclk. False-path the asynchronous reset into the first flop. The chain's own
# shift is synchronous to dclk and timed normally.
set INST  "<u_rst_sync>"
set DSTCK "<dst_clk>"

# Asynchronous reset assertion path.
set_false_path -to [get_pins ${INST}/sync_q_reg[*]/CLR]

# If raw_rst_n originates in another clock domain, also false-path its data
# arc into the first stage:
# set_false_path -from [get_ports <raw_rst_n>] -to [get_pins ${INST}/sync_q_reg[0]/D]

# set_property ASYNC_REG true [get_cells ${INST}/sync_q_reg[*]]
