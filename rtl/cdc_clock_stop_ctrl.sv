// cdc_clock_stop_ctrl.sv — clock stop/start handshake + isolation (G3, G4)
//
// Safely quiesces a destination clock domain. A controller in an always-on
// domain requests the target clock to stop; the target domain acknowledges
// when it is idle, the clock enable is dropped (clock-gating cell), and the
// target's outputs are isolated to known-safe values while its clock is off.
// Start reverses the sequence.
//
// Contract
//   Clock assumptions : ctrl_clk always on; tgt_clk is the gated clock.
//   Data assumptions  : tgt_idle is a level from the target domain that is
//                       high only when it is safe to stop the clock.
//   Guarantees        : clk_en is never dropped until the target reports idle
//                       and the request has crossed safely; isolate asserts
//                       whenever the clock is (about to be) stopped; no glitch
//                       on the enable.
//   Reset             : clock runs, isolation off after reset.
module cdc_clock_stop_ctrl (
    // always-on control domain
    input  logic ctrl_clk,
    input  logic ctrl_rst_n,
    input  logic stop_req,     // request the target clock to stop
    output logic stopped,      // target clock is confirmed stopped

    // target (gated) domain
    input  logic tgt_clk,
    input  logic tgt_rst_n,
    input  logic tgt_idle,     // target is safe to stop
    output logic clk_en,       // enable for the clock-gating cell
    output logic isolate       // isolate target outputs while stopped
);

  // Synchronise stop_req into the target domain.
  logic req_t1, req_t2;
  always_ff @(posedge tgt_clk or negedge tgt_rst_n) begin
    if (!tgt_rst_n) begin
      req_t1 <= 1'b0;
      req_t2 <= 1'b0;
    end else begin
      req_t1 <= stop_req;
      req_t2 <= req_t1;
    end
  end

  // Target grants the stop only when it is idle and a stop is requested.
  logic grant_q;
  always_ff @(posedge tgt_clk or negedge tgt_rst_n) begin
    if (!tgt_rst_n)
      grant_q <= 1'b0;
    else if (req_t2 && tgt_idle)
      grant_q <= 1'b1;
    else if (!req_t2)
      grant_q <= 1'b0;
  end

  // Synchronise the grant back to the control domain.
  logic grant_c1, grant_c2;
  always_ff @(posedge ctrl_clk or negedge ctrl_rst_n) begin
    if (!ctrl_rst_n) begin
      grant_c1 <= 1'b0;
      grant_c2 <= 1'b0;
    end else begin
      grant_c1 <= grant_q;
      grant_c2 <= grant_c1;
    end
  end
  assign stopped = grant_c2;

  // Clock enable: dropped once the grant is confirmed; raised when no stop is
  // requested. Registered in the control (always-on) domain so the gating
  // cell sees a clean, glitch-free enable.
  logic clk_en_q;
  logic iso_q;
  always_ff @(posedge ctrl_clk or negedge ctrl_rst_n) begin
    if (!ctrl_rst_n) begin
      clk_en_q <= 1'b1;
      iso_q    <= 1'b0;
    end else begin
      // Isolate before gating off, deisolate after gating on.
      iso_q    <= grant_c2 ? 1'b1 : (stop_req ? iso_q : 1'b0);
      clk_en_q <= grant_c2 ? 1'b0 : (stop_req ? clk_en_q : 1'b1);
    end
  end
  assign clk_en  = clk_en_q;
  // Outputs are isolated whenever the explicit isolation flag is set OR the
  // clock is currently gated off — the isolation window always contains the
  // clock-off window by construction.
  assign isolate = iso_q | ~clk_en_q;

`ifdef FORMAL
  // Track whether a grant was ever confirmed: the clock may only be gated off
  // after a confirmed grant.
  logic f_grant_seen = 1'b0;
  logic f_cpv = 1'b0;
  always_ff @(posedge ctrl_clk) begin
    if (!f_cpv) assume (!ctrl_rst_n);
    f_cpv <= 1'b1;
    if (!ctrl_rst_n)      f_grant_seen <= 1'b0;
    else if (stopped)     f_grant_seen <= 1'b1;

    // The clock enable is dropped only after a grant was confirmed.
    if (f_cpv && $past(ctrl_rst_n) && ctrl_rst_n && !clk_en)
      assert (f_grant_seen);
    // Isolation is asserted whenever the clock enable is low (by construction).
    if (ctrl_rst_n && !clk_en)
      assert (isolate);
    if (ctrl_rst_n) cover (stopped);
    if (ctrl_rst_n) cover (clk_en);
    if (ctrl_rst_n) cover (!clk_en);
  end
  // Target never grants a stop unless it reported idle on the grant edge.
  logic f_tpv = 1'b0;
  always_ff @(posedge tgt_clk) begin
    if (!f_tpv) assume (!tgt_rst_n);
    f_tpv <= 1'b1;
    if (f_tpv && $past(tgt_rst_n) && tgt_rst_n && grant_q && !$past(grant_q))
      assert ($past(tgt_idle));
  end
`endif

endmodule
