// cdc_pkg.sv — shared helpers for the CDC primitive library
//
// Contract
//   Clock assumptions : none (pure functions)
//   Guarantees        : bin2gray / gray2bin are exact inverses for all widths
//
// SystemVerilog IEEE 1800-2017.
`ifndef CDC_PKG_SV
`define CDC_PKG_SV

package cdc_pkg;

  // Binary -> reflected Gray code. Exactly one bit changes between adjacent
  // binary values, which is what makes a Gray-coded bus safe to synchronise
  // bit-by-bit across a clock boundary.
  function automatic logic [31:0] bin2gray(input logic [31:0] b, input integer w);
    logic [31:0] g;
    g = b ^ (b >> 1);
    // mask to the requested width
    bin2gray = g & ((w >= 32) ? 32'hFFFF_FFFF : ((32'h1 << w) - 32'h1));
  endfunction

  // Reflected Gray code -> binary (inverse of bin2gray).
  function automatic logic [31:0] gray2bin(input logic [31:0] g, input integer w);
    logic [31:0] b;
    integer i;
    b = g;
    for (i = 1; i < 32; i = i + 1) begin
      b = b ^ (g >> i);
    end
    gray2bin = b & ((w >= 32) ? 32'hFFFF_FFFF : ((32'h1 << w) - 32'h1));
  endfunction

endpackage

`endif
