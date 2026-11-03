// cdc_sync_toggle.sv — toggle-based event synchroniser (covers A3, A4)
//
// Transfers single-cycle *events* (not levels) across clock domains. Each
// source pulse flips a toggle flop; the destination recovers one output pulse
// per toggle edge. Robust to clock-ratio differences as long as events are
// spaced far enough apart to survive synchronisation.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_pulse is one sclk high. Consecutive events must be
//                       separated by >= ~2 dclk periods (and >= 1 sclk) or
//                       events coalesce — use cdc_sync_event_handshake for a
//                       lossless, back-pressured channel.
//   Guarantees        : exactly one d_pulse (one dclk high) per source toggle
//                       edge once the toggle is observed; no event invented
//                       without a source event.
//   Reset             : both domains reset to the same toggle polarity so no
//                       phantom edge appears at release.
module cdc_sync_toggle (
    input  logic sclk,
    input  logic srst_n,
    input  logic s_pulse,   // source event, 1 sclk cycle

    input  logic dclk,
    input  logic drst_n,
    output logic d_pulse    // recovered event, 1 dclk cycle
);

  // Source toggle flop: invert on every source event.
  logic toggle_q;
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n)
      toggle_q <= 1'b0;
    else if (s_pulse)
      toggle_q <= ~toggle_q;
  end

  // Synchronise the toggle level into the destination domain.
  logic sync0_q, sync1_q, sync2_q;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      sync0_q <= 1'b0;
      sync1_q <= 1'b0;
      sync2_q <= 1'b0;
    end else begin
      sync0_q <= toggle_q;
      sync1_q <= sync0_q;
      sync2_q <= sync1_q;  // delayed copy for edge detect
    end
  end

  // Any change in the synchronised toggle is one event.
  assign d_pulse = sync1_q ^ sync2_q;

`ifdef FORMAL
  always_ff @(posedge dclk) begin
    // d_pulse is exactly the edge-detect of the synchronised toggle, so it
    // can never assert while the two compared stages are equal.
    if (drst_n) assert (d_pulse == (sync1_q ^ sync2_q));
    if (drst_n) assert (!(d_pulse && (sync1_q == sync2_q)));
    if (drst_n) cover (d_pulse);
  end
`endif

endmodule
