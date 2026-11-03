// cdc_sync_pulse.sv — pulse synchroniser with optional stretch (covers A4, A5)
//
// Like cdc_sync_toggle, but additionally guarantees the recovered pulse is
// visible for DST_WIDTH destination cycles (pulse-stretch). Useful when the
// destination consumer needs a wider strobe (e.g. slow sampling logic).
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_pulse is one sclk high; events spaced so the
//                       stretched output of one does not overlap the next.
//   Guarantees        : one d_pulse burst of exactly DST_WIDTH dclk cycles
//                       per source event.
module cdc_sync_pulse #(
    parameter int unsigned DST_WIDTH = 1  // recovered pulse width, dclk cycles
) (
    input  logic sclk,
    input  logic srst_n,
    input  logic s_pulse,

    input  logic dclk,
    input  logic drst_n,
    output logic d_pulse
);

  // synthesis translate_off
  initial if (DST_WIDTH < 1) $fatal(1, "cdc_sync_pulse: DST_WIDTH must be >= 1");
  // synthesis translate_on

  // Reuse the toggle synchroniser to recover a 1-cycle event.
  logic d_event;
  cdc_sync_toggle u_tog (
      .sclk    (sclk),
      .srst_n  (srst_n),
      .s_pulse (s_pulse),
      .dclk    (dclk),
      .drst_n  (drst_n),
      .d_pulse (d_event)
  );

  generate
    if (DST_WIDTH == 1) begin : g_width1
      assign d_pulse = d_event;
    end else begin : g_stretch
      // Down-counter stretch: load on event, hold output while non-zero.
      localparam int unsigned CW = $clog2(DST_WIDTH);
      logic [CW-1:0] cnt_q;
      always_ff @(posedge dclk or negedge drst_n) begin
        if (!drst_n)
          cnt_q <= '0;
        else if (d_event)
          cnt_q <= CW'(DST_WIDTH - 1);
        else if (cnt_q != '0)
          cnt_q <= cnt_q - 1'b1;
      end
      assign d_pulse = d_event | (cnt_q != '0);
    end
  endgenerate

`ifdef FORMAL
  always_ff @(posedge dclk) if (drst_n) cover (d_pulse);
  generate
    if (DST_WIDTH == 1) begin : g_chk1
      always_ff @(posedge dclk)
        if (drst_n) assert (d_pulse == d_event);
    end else begin : g_chkN
      // Stretched output is the OR of the event and a non-zero down-counter.
      always_ff @(posedge dclk)
        if (drst_n) assert (d_pulse == (d_event | (g_stretch.cnt_q != '0)));
    end
  endgenerate
`endif

endmodule
