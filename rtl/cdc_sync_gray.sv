// cdc_sync_gray.sv — Gray-coded bus / counter synchroniser (covers B1, D1)
//
// Safely transfers a monotonic multi-bit value (typically a counter) across
// a clock boundary by Gray-encoding it so only one bit ever changes per
// source step. Each Gray bit is synchronised independently; the destination
// decodes back to binary.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_bin changes by at most one increment/decrement per
//                       sclk cycle (monotonic, unit steps). Arbitrary jumps
//                       break the single-bit-change guarantee — use a
//                       handshake for non-monotonic buses.
//   Guarantees        : d_bin is always a value s_bin actually held; during a
//                       crossing the destination sees either the old or the
//                       new value, never a corrupted intermediate.
//   Reset             : both domains reset to zero.
module cdc_sync_gray #(
    parameter int unsigned WIDTH = 8
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic [WIDTH-1:0] s_bin,    // monotonic source value

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_bin     // synchronised value, dclk domain
);

  function automatic logic [WIDTH-1:0] bin2gray(input logic [WIDTH-1:0] b);
    bin2gray = b ^ (b >> 1);
  endfunction

  function automatic logic [WIDTH-1:0] gray2bin(input logic [WIDTH-1:0] g);
    integer i;
    gray2bin = g;
    for (i = 1; i < WIDTH; i = i + 1)
      gray2bin = gray2bin ^ (g >> i);
  endfunction

  // Register the source value as Gray in its own domain.
  logic [WIDTH-1:0] gray_q;
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n)
      gray_q <= '0;
    else
      gray_q <= bin2gray(s_bin);
  end

  // Two-stage synchroniser on the Gray word.
  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] gray_sync1, gray_sync2;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      gray_sync1 <= '0;
      gray_sync2 <= '0;
    end else begin
      gray_sync1 <= gray_q;
      gray_sync2 <= gray_sync1;
    end
  end

  assign d_bin = gray2bin(gray_sync2);

`ifdef FORMAL
  (* anyconst *) logic [WIDTH-1:0] f_probe;
  logic f_spv = 1'b0;
  always_ff @(posedge sclk) begin
`ifdef CDC_SYNC_GRAY_FTOP
    if (!f_spv) assume (!srst_n);
`endif
    f_spv <= 1'b1;
    // bin2gray/gray2bin are exact inverses for an arbitrary constant value.
    assert (gray2bin(bin2gray(f_probe)) == f_probe);
    // The registered Gray word always decodes to a legal binary value.
    if (srst_n) assert (bin2gray(gray2bin(gray_q)) == gray_q);
    // The registered Gray word is the Gray encoding of the previous s_bin.
    if (f_spv && $past(srst_n) && srst_n)
      assert (gray_q == bin2gray($past(s_bin)));
  end
  always_ff @(posedge dclk)
    if (drst_n) cover (d_bin != '0);
`endif

endmodule
