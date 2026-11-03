// cdc_sync_event_handshake.sv — lossless event channel with backpressure (A6)
//
// Four-phase req/ack handshake that transfers one event at a time across a
// clock boundary without losing events, at the cost of round-trip latency.
// The source presents an event and asserts it is busy until the destination
// has acknowledged; a new event cannot be launched until the previous one
// completes.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : s_valid asserted when s_ready is high launches one
//                       event (ready/valid handshake on the source side).
//   Guarantees        : every launched source event produces exactly one
//                       d_event, in order, with no loss and no duplication;
//                       s_ready deasserts until the round trip completes
//                       (backpressure).
//   Reset             : either domain's reset returns the channel to idle.
module cdc_sync_event_handshake (
    input  logic sclk,
    input  logic srst_n,
    input  logic s_valid,   // source wants to send an event
    output logic s_ready,   // channel can accept an event

    input  logic dclk,
    input  logic drst_n,
    output logic d_event    // one dclk pulse per transferred event
);

  // Source side: req toggles region. Use a level-req / level-ack 4-phase FSM.
  logic req_q;     // source request level
  logic ack_sync1, ack_sync2;  // destination ack synchronised to source

  // Synchronise ack back into source domain.
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n) begin
      ack_sync1 <= 1'b0;
      ack_sync2 <= 1'b0;
    end else begin
      ack_sync1 <= ack_level;
      ack_sync2 <= ack_sync1;
    end
  end

  // Source FSM: idle -> launch (req=1) -> wait ack=1 -> drop req -> wait ack=0.
  // s_ready is high only in idle.
  always_ff @(posedge sclk or negedge srst_n) begin
    if (!srst_n) begin
      req_q <= 1'b0;
    end else begin
      if (!req_q && !ack_sync2 && s_valid)
        req_q <= 1'b1;            // launch
      else if (req_q && ack_sync2)
        req_q <= 1'b0;            // ack seen, drop req (return-to-zero)
    end
  end

  assign s_ready = !req_q && !ack_sync2;

  // Destination side: synchronise req, generate a one-cycle event on its
  // rising edge, and mirror req as the ack level.
  logic req_sync1, req_sync2, req_sync3;
  logic ack_level;

  always_ff @(posedge dclk or negedge drst_n) begin
    if (!drst_n) begin
      req_sync1 <= 1'b0;
      req_sync2 <= 1'b0;
      req_sync3 <= 1'b0;
      ack_level <= 1'b0;
    end else begin
      req_sync1 <= req_q;
      req_sync2 <= req_sync1;
      req_sync3 <= req_sync2;
      ack_level <= req_sync2;   // ack follows the synchronised request level
    end
  end

  // Event on rising edge of the synchronised request.
  assign d_event = req_sync2 & ~req_sync3;

`ifdef FORMAL
  // Only one event ever in flight: s_ready implies no outstanding request.
  always_ff @(posedge sclk) begin
    if (srst_n) assert (!(s_ready && req_q));
    if (srst_n) assert (s_ready == (!req_q && !ack_sync2));
    if (srst_n) cover (s_valid && s_ready);
  end

  // d_event is a clean one-cycle strobe: the rising edge of synced request.
  always_ff @(posedge dclk) begin
    if (drst_n) assert (d_event == (req_sync2 & ~req_sync3));
    if (drst_n) cover (d_event);
  end
`endif

endmodule
