// cdc_bus_handshake.sv — full req/ack data-bus synchroniser (covers B2–B5)
//
// Transfers a multi-bit data word across a clock boundary using a four-phase
// req/ack handshake. The data bus is held stable by the source for the whole
// handshake, so only the single-bit req/ack controls actually cross domains —
// the data itself is sampled by the destination only once req is known stable.
// This is the general-purpose safe transfer for arbitrary (non-monotonic)
// multi-bit values.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : ready/valid on each side. s_data must be stable from
//                       the cycle s_valid&&s_ready until the next s_ready.
//   Guarantees        : every accepted source word is delivered exactly once,
//                       in order, uncorrupted (bits sampled from one stable
//                       value — no multi-bit skew), with backpressure.
//   Reset             : either reset returns the channel to idle.
module cdc_bus_handshake #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic [WIDTH-1:0] s_data,
    input  logic             s_valid,
    output logic             s_ready,

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_data,
    output logic             d_valid,   // 1 dclk pulse when d_data is fresh
    input  logic             d_ready    // destination consumed d_data
);

  // Captured, stable source word held for the whole handshake.
  logic [WIDTH-1:0] data_hold;
  logic             req_q;
  logic             ack_sync1, ack_sync2;

  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n) begin
      data_hold <= '0;
      req_q     <= 1'b0;
      ack_sync1 <= 1'b0;
      ack_sync2 <= 1'b0;
    end else begin
      ack_sync1 <= ack_level;
      ack_sync2 <= ack_sync1;
      if (s_ready && s_valid) begin
        data_hold <= s_data;    // latch stable payload
        req_q     <= 1'b1;      // launch
      end else if (req_q && ack_sync2) begin
        req_q     <= 1'b0;      // ack seen, return to zero
      end
    end
  end

  assign s_ready = !req_q && !ack_sync2;

  // Destination: synchronise req, sample held data on the rising edge, and
  // present d_valid for one cycle. ack mirrors the synchronised req level.
  logic req_sync1, req_sync2, req_sync3;
  logic ack_level;

  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      req_sync1 <= 1'b0;
      req_sync2 <= 1'b0;
      req_sync3 <= 1'b0;
      ack_level <= 1'b0;
      d_data    <= '0;
    end else begin
      req_sync1 <= req_q;
      req_sync2 <= req_sync1;
      req_sync3 <= req_sync2;
      // data_hold is stable while req is high; safe to sample on the edge.
      if (req_sync2 & ~req_sync3)
        d_data <= data_hold;
      // Acknowledge once the consumer has taken the word (or immediately if
      // no backpressure is used — d_ready tied high).
      if (req_sync2 && (d_valid_q ? d_ready : 1'b1))
        ack_level <= 1'b1;
      else if (!req_sync2)
        ack_level <= 1'b0;
    end
  end

  // d_valid is a one-cycle strobe on fresh data.
  logic d_valid_q;
  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n)
      d_valid_q <= 1'b0;
    else
      d_valid_q <= req_sync2 & ~req_sync3;
  end
  assign d_valid = req_sync2 & ~req_sync3;

`ifdef FORMAL
  // Single word in flight — s_ready implies quiescent, never ready while a
  // request is outstanding.
  always_ff @(posedge sclk) begin
    if (srst_n) assert (!(s_ready && req_q));
    if (srst_n) assert (s_ready == (!req_q && !ack_sync2));
    if (srst_n) cover (s_valid && s_ready);
  end
  // Data-integrity oracle: the source always drives one constant payload, so
  // whatever the destination delivers must equal that exact value. Under the
  // documented coordinated-reset contract (common reset or coordinated
  // release), model both domains starting in reset with tied resets.
  (* anyconst *) logic [WIDTH-1:0] f_data;
  logic f_dpv = 1'b0;
  always_ff @(posedge dclk) begin
`ifdef CDC_BUS_HANDSHAKE_FTOP
    if (!f_dpv) assume (!drst_n && !srst_n);
    assume (drst_n == srst_n);
    assume (s_data == f_data);   // source holds the constant payload
`endif
    f_dpv <= 1'b1;
    if (drst_n) assert (d_valid == (req_sync2 & ~req_sync3));
`ifdef CDC_BUS_HANDSHAKE_FTOP
    // d_data is registered, so it carries the delivered word the cycle AFTER
    // the d_valid strobe. It must then equal the (constant) source payload.
    if (f_dpv && drst_n && $past(drst_n) && $past(d_valid))
      assert (d_data == f_data);
`endif
    if (drst_n) cover (d_valid);
  end
`endif

endmodule
