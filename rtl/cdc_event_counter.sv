// cdc_event_counter.sv — lossless event-count transfer (covers D3)
//
// Accumulates source-domain events into a Gray-coded counter and exposes the
// running total in the destination domain. No event is lost even when the
// destination samples slowly: the destination reads a monotonically
// increasing count and derives deltas itself.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_event is one sclk high per event. At most one
//                       increment per sclk cycle keeps the counter monotonic
//                       by unit steps (safe for Gray crossing).
//   Guarantees        : d_count is a value the source counter actually held;
//                       it never decreases (until wrap) and never skips the
//                       true total by more than the in-flight synchroniser
//                       latency.
//   Reset             : both domains reset to zero.
module cdc_event_counter #(
    parameter int unsigned WIDTH = 16
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic             s_event,

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_count
);

  logic [WIDTH-1:0] cnt_q;
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n)
      cnt_q <= '0;
    else if (s_event)
      cnt_q <= cnt_q + 1'b1;   // monotonic unit steps -> Gray-safe
  end

  cdc_sync_gray #(.WIDTH(WIDTH)) u_gray (
      .sclk   (sclk),
      .srst_n (srst_n),
      .s_bin  (cnt_q),
      .dclk   (dclk),
      .drst_n (drst_n),
      .d_bin  (d_count)
  );

`ifdef FORMAL
  logic f_spv = 1'b0;
  always_ff @(posedge sclk) begin
    if (!f_spv) assume (!srst_n);
    f_spv <= 1'b1;
    // The source counter only moves by 0 or +1 per sclk cycle (monotonic unit
    // steps), the precondition that makes the Gray crossing safe.
    if (f_spv && srst_n && $past(srst_n))
      assert ((cnt_q == $past(cnt_q)) ||
              (cnt_q == WIDTH'($past(cnt_q) + 1'b1)));
  end
  always_ff @(posedge dclk) if (drst_n) cover (d_count != '0);
`endif

endmodule
