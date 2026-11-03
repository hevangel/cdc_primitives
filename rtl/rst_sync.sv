// rst_sync.sv — async-assert / sync-deassert reset synchroniser (covers F1)
//
// Produces a clean, glitch-free active-low reset for one clock domain. The
// reset asserts asynchronously the instant the raw reset drops (so logic is
// forced into reset even before a clock edge), and deasserts synchronously,
// aligned to dclk and held for STAGES cycles so all flops release on the same
// edge — preventing metastable reset release.
//
// Contract
//   Clock assumptions : dclk may be running or stopped when raw_rst_n
//                       asserts; deassertion is synchronised to dclk.
//   Guarantees        : rst_n asserts asynchronously with raw_rst_n; deasserts
//                       only on a dclk edge, STAGES cycles after raw_rst_n
//                       goes high; no partial/ glitchy release.
//   Reset             : raw_rst_n is the asynchronous reset input (active low).
module rst_sync #(
    parameter int unsigned STAGES = 2
) (
    input  logic dclk,
    input  logic raw_rst_n,   // asynchronous reset in, active low
    output logic rst_n        // synchronised reset out, active low
);

  // synthesis translate_off
  initial if (STAGES < 2) $fatal(1, "rst_sync: STAGES must be >= 2");
  // synthesis translate_on

  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_q;

  // Async assert (clear on raw_rst_n low), sync deassert (shift 1s in).
  always_ff @(posedge dclk or negedge raw_rst_n) begin
    if (!raw_rst_n)
      sync_q <= '0;
    else
      sync_q <= {sync_q[STAGES-2:0], 1'b1};
  end

  assign rst_n = sync_q[STAGES-1];

`ifdef FORMAL
  logic f_valid = 1'b0;
  always_ff @(posedge dclk) begin
    f_valid <= 1'b1;
    // Whenever the raw reset is low, the output is low (async assert).
    if (!raw_rst_n) assert (rst_n == 1'b0);
    // Output can only be high if the raw reset is high.
    assert (!(rst_n && !raw_rst_n));
    // After a full window of clocks with raw reset high, reset is released.
    cover (rst_n);
    cover (f_valid && !rst_n);
  end
`endif

endmodule
