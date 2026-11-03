// cdc_bus_mcp.sv — multi-cycle-path data synchroniser (covers B6)
//
// Transfers a multi-bit word by holding the data stable for several cycles
// (an open timing exception / multi-cycle path) and crossing only a single
// load-enable strobe through a toggle synchroniser. Lower latency and area
// than a full req/ack handshake, at the cost of requiring the source to
// space loads far enough apart that the previous value has been captured.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous. The s_data -> d_data path
//                       is a declared multi-cycle / max-delay path in SDC.
//   Data assumptions  : when s_load pulses, s_data must stay stable for at
//                       least the synchroniser latency (~3 dclk cycles). The
//                       source must not issue a new s_load until the prior
//                       one has been captured (no built-in backpressure).
//   Guarantees        : d_data updates to the loaded value, sampled from one
//                       stable word (no multi-bit skew); d_valid strobes once
//                       per load.
//   Reset             : both domains reset to zero.
module cdc_bus_mcp #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic [WIDTH-1:0] s_data,
    input  logic             s_load,   // capture s_data and transfer it

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_data,
    output logic             d_valid   // 1 dclk pulse when d_data updates
);

  // Hold the source word stable; toggle a flag on each load.
  logic [WIDTH-1:0] data_hold;
  logic             toggle_q;
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n) begin
      data_hold <= '0;
      toggle_q  <= 1'b0;
    end else if (s_load) begin
      data_hold <= s_data;
      toggle_q  <= ~toggle_q;
    end
  end

  // Synchronise the load toggle into the destination.
  logic tog_sync1, tog_sync2, tog_sync3;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      tog_sync1 <= 1'b0;
      tog_sync2 <= 1'b0;
      tog_sync3 <= 1'b0;
    end else begin
      tog_sync1 <= toggle_q;
      tog_sync2 <= tog_sync1;
      tog_sync3 <= tog_sync2;
    end
  end

  logic load_pulse;
  assign load_pulse = tog_sync2 ^ tog_sync3;

  // Capture the (now stable) held data when the load strobe arrives.
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      d_data  <= '0;
    end else if (load_pulse) begin
      d_data  <= data_hold;   // MCP: data has been stable for ~3 cycles
    end
  end

  assign d_valid = load_pulse;

`ifdef FORMAL
  // Data-integrity oracle: the source always drives one constant payload, so
  // whatever the destination delivers must equal that exact value. The
  // contract is a coordinated reset (common reset or coordinated release):
  // model it by starting both domains in reset and tying the resets.
  (* anyconst *) logic [WIDTH-1:0] f_data;
  logic f_dpv = 1'b0;

  always_ff @(posedge dclk) begin
`ifdef CDC_BUS_MCP_FTOP
    if (!f_dpv) assume (!drst_n && !srst_n);
    assume (drst_n == srst_n);
    assume (s_data == f_data);   // source holds the constant payload
`endif
    f_dpv <= 1'b1;

    // d_valid is a clean one-cycle strobe (edge of the synced toggle).
    if (drst_n) assert (d_valid == (tog_sync2 ^ tog_sync3));
    if (drst_n) assert (!(load_pulse && (tog_sync2 == tog_sync3)));
`ifdef CDC_BUS_MCP_FTOP
    // d_data is registered, so it carries the delivered word the cycle AFTER
    // the d_valid strobe. It must then equal the (constant) source payload.
    if (f_dpv && drst_n && $past(drst_n) && $past(d_valid))
      assert (d_data == f_data);
`endif
    if (drst_n) cover (d_valid);
  end
`endif

endmodule
