// cdc_sync_sticky.sv — sticky event / status synchroniser (covers A7, D4)
//
// Captures a short source-domain event into a sticky flag that stays set
// until the destination domain clears it. Guarantees a transient source
// pulse that is too narrow to survive a plain 2-FF synchroniser is never
// lost — ideal for fault/error status bits.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_set is a source event (any width >= 1 sclk).
//   Guarantees        : once s_set is seen, d_status stays 1 until d_clear is
//                       asserted in the destination domain; a set that arrives
//                       is never dropped.
//   Reset             : either domain's reset clears the sticky flag.
module cdc_sync_sticky (
    input  logic sclk,
    input  logic srst_n,
    input  logic s_set,      // source event to latch

    input  logic dclk,
    input  logic drst_n,
    input  logic d_clear,    // destination clears the latched status
    output logic d_status    // synchronised sticky status
);

  // Source sticky flag. Set on event; cleared when the destination's clear
  // request has been synchronised back and observed.
  logic sticky_q;
  logic clr_sync1, clr_sync2;

  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n) begin
      sticky_q  <= 1'b0;
      clr_sync1 <= 1'b0;
      clr_sync2 <= 1'b0;
    end else begin
      clr_sync1 <= d_clear_level;
      clr_sync2 <= clr_sync1;
      if (s_set)
        sticky_q <= 1'b1;
      else if (clr_sync2)
        sticky_q <= 1'b0;
    end
  end

  // Synchronise the sticky flag into the destination domain.
  logic sts_sync1, sts_sync2;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      sts_sync1 <= 1'b0;
      sts_sync2 <= 1'b0;
    end else begin
      sts_sync1 <= sticky_q;
      sts_sync2 <= sts_sync1;
    end
  end
  assign d_status = sts_sync2;

  // Destination clear is held until the source flag has actually dropped,
  // forming a safe 4-phase clear handshake (level, not pulse).
  logic d_clear_level;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n)
      d_clear_level <= 1'b0;
    else if (d_clear && d_status)
      d_clear_level <= 1'b1;        // request clear
    else if (!sts_sync2)
      d_clear_level <= 1'b0;        // source flag gone, drop the request
  end

`ifdef FORMAL
  logic f_spv = 1'b0;
  always_ff @(posedge sclk) begin
    if (!f_spv) assume (!srst_n);
    f_spv <= 1'b1;
    // A set event latches the sticky flag by the next cycle: no event lost.
    if (f_spv && srst_n && $past(srst_n) && $past(s_set)) assert (sticky_q);
  end

  logic f_dpv = 1'b0;
  logic f_dstatus_q;
  always_ff @(posedge dclk) begin
    if (!f_dpv) assume (!drst_n);
    f_dpv       <= 1'b1;
    f_dstatus_q <= d_status;
    // d_status is exactly the destination synchroniser tail.
    if (drst_n) assert (d_status == sts_sync2);
    if (drst_n) cover (d_status);
    // Status fell this cycle (a clear completed).
    if (drst_n && f_dpv) cover (f_dstatus_q && !d_status);
  end
`endif

endmodule
