// cdc_sync_bit.sv — N-flop level synchroniser (covers taxonomy A1, A2)
//
// Transfers a single-bit *level* signal from a source domain into the
// destination clock domain through an N-stage flip-flop chain. The first
// stage may go metastable; the remaining stages give it time to settle.
//
// Contract
//   Clock assumptions : dclk asynchronous to the source of din.
//   Data assumptions  : din is a level. Pulses narrower than ~1.5 dclk
//                       periods may be missed — use cdc_sync_pulse for pulses.
//   Guarantees        : dout is a registered, metastability-hardened copy of
//                       din, delayed by STAGES dclk cycles. No combinational
//                       path from din to dout.
//   Reset             : async-assert / sync observe via rst_n (active low),
//                       clears the chain to RST_VAL.
//   Physical          : tag the chain with ASYNC_REG so the flops are placed
//                       together; constrain din as a false/max-delay path.
//
// Parameters
//   STAGES  : number of synchroniser flops (>= 2). 3 for high-MTBF designs.
//   RST_VAL : reset value of the chain.
module cdc_sync_bit #(
    parameter int unsigned STAGES  = 2,
    parameter logic        RST_VAL = 1'b0
) (
    input  logic dclk,    // destination clock
    input  logic drst_n,  // destination reset, active low
    input  logic din,     // source-domain level (asynchronous)
    output logic dout     // synchronised level in dclk domain
);

  // synthesis translate_off
  initial begin
    if (STAGES < 2)
      $fatal(1, "cdc_sync_bit: STAGES must be >= 2 (got %0d)", STAGES);
  end
  // synthesis translate_on

  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_q;

  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n)
      sync_q <= {STAGES{RST_VAL}};
    else
      sync_q <= {sync_q[STAGES-2:0], din};
  end

  assign dout = sync_q[STAGES-1];

`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always_ff @(posedge dclk) begin
    if (!f_past_valid) assume (!drst_n);  // start in reset
    f_past_valid <= 1'b1;

    // dout is the tail of the synchroniser chain (structural identity).
    assert (dout == sync_q[STAGES-1]);
    // The chain is a pure shift register: the last stage is the previous
    // value of the second-to-last stage (no extra logic on the path).
    if (f_past_valid && $past(drst_n) && drst_n)
      assert (sync_q[STAGES-1] == $past(sync_q[STAGES-2]));
    // Non-vacuity: both logic levels can reach the output.
    if (drst_n) cover (dout == 1'b1);
    if (drst_n) cover (dout == 1'b0);
  end
`endif

endmodule
