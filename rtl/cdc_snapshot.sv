// cdc_snapshot.sv — coherent multi-signal snapshot synchroniser (B7, D2)
//
// Captures a group of related source-domain signals atomically and transfers
// the whole snapshot across the clock boundary using one MCP load strobe, so
// the destination always sees a mutually-consistent set (e.g. a coherent
// performance-counter tuple), never a mix of old and new fields.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_capture pulses to take a snapshot of s_vector.
//   Guarantees        : d_vector always holds a snapshot that existed at one
//                       single source cycle (field coherence); d_valid strobes
//                       once per captured snapshot.
//   Reset             : both domains reset to zero.
module cdc_snapshot #(
    parameter int unsigned WIDTH = 64
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic [WIDTH-1:0] s_vector,
    input  logic             s_capture,

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_vector,
    output logic             d_valid
);

  // A snapshot is exactly an MCP transfer of the whole vector.
  cdc_bus_mcp #(.WIDTH(WIDTH)) u_mcp (
      .sclk   (sclk),
      .srst_n (srst_n),
      .s_data (s_vector),
      .s_load (s_capture),
      .dclk   (dclk),
      .drst_n (drst_n),
      .d_data (d_vector),
      .d_valid(d_valid)
  );

`ifdef FORMAL
  always_ff @(posedge dclk) if (drst_n) cover (d_valid);
`endif

endmodule
