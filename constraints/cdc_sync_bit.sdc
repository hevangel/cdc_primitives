# SDC template — cdc_sync_bit (N-flop level synchroniser)
#
# Fill in:
#   INST  : hierarchical path to the cdc_sync_bit instance
#   SRCCK : clock that drives the source of `din`
#   DSTCK : destination clock `dclk`
set INST  "<u_cdc_sync_bit>"
set SRCCK "<src_clk>"
set DSTCK "<dst_clk>"

# The crossing is din -> sync_q[0]. There is no valid timing relationship, so
# false-path it. The remaining sync_q stages are fully synchronous to DSTCK and
# are timed normally.
set_false_path -to [get_pins ${INST}/sync_q_reg[0]/D]

# Keep the synchroniser chain physically together (Vivado honours the RTL
# ASYNC_REG attribute; this makes the intent explicit for other flows).
# set_property ASYNC_REG true [get_cells ${INST}/sync_q_reg[*]]

# Async reset: assert is asynchronous, so false-path the reset pin.
set_false_path -to [get_pins ${INST}/sync_q_reg[*]/CLR]

# (Clocks must already be declared mutually asynchronous at top level:)
# set_clock_groups -asynchronous -group [get_clocks $SRCCK] -group [get_clocks $DSTCK]
