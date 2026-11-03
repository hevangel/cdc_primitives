// cdc_pingpong.sv — double-buffer (ping-pong) block transfer (covers C4)
//
// Two buffers alternate between the producer (source domain) and consumer
// (destination domain). While the source fills one buffer, the destination
// reads the other; a bank-select bit is crossed with an MCP handshake on each
// swap. Decouples a block producer from a block consumer without a deep FIFO.
//
// Contract
//   Clock assumptions : wclk and rclk asynchronous.
//   Data assumptions  : source writes a full block then pulses s_swap; it must
//                       not begin the next block until d_ready_bank indicates
//                       the consumer released its buffer.
//   Guarantees        : the consumer always reads a completely-written buffer
//                       (no tearing); bank ownership never overlaps.
//   Reset             : both domains reset; source owns bank 0 after reset.
module cdc_pingpong #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned DEPTH = 16
) (
    input  logic             wclk,
    input  logic             wrst_n,
    input  logic             wr_en,
    input  logic [$clog2(DEPTH)-1:0] wr_addr, // explicit write address
    input  logic [WIDTH-1:0] wr_data,
    input  logic             s_swap,       // producer finished this block
    output logic             w_ready,      // safe to fill and swap again
    output logic             w_bank,       // bank the producer owns

    input  logic             rclk,
    input  logic             rrst_n,
    input  logic [$clog2(DEPTH)-1:0] rd_addr,
    output logic [WIDTH-1:0] rd_data,
    output logic             r_valid,      // a full block is ready to read
    input  logic             r_done,       // consumer finished reading
    output logic             r_bank        // bank the consumer owns
);

  // Two memory banks.
  logic [WIDTH-1:0] mem0 [DEPTH];
  logic [WIDTH-1:0] mem1 [DEPTH];

  // Producer writes wr_data to wr_addr in the bank it currently owns; a swap
  // hands that bank to the consumer and takes the other.
  logic wbank_q;
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbank_q <= 1'b0;
    end else begin
      if (wr_en) begin
        if (!wbank_q) mem0[wr_addr] <= wr_data;
        else          mem1[wr_addr] <= wr_data;
      end
      if (s_swap) wbank_q <= ~wbank_q;
    end
  end
  assign w_bank = wbank_q;

  // Cross the producer's bank select to the consumer with an MCP transfer.
  logic c_bank;
  logic c_valid;
  // The MCP captures wbank_q at the s_swap edge, i.e. the bank that was being
  // written and is now complete. That captured value IS the bank the consumer
  // should read.
  cdc_bus_mcp #(.WIDTH(1)) u_bank (
      .sclk   (wclk),
      .srst_n (wrst_n),
      .s_data (wbank_q),       // the just-completed bank (sampled at the swap)
      .s_load (s_swap),
      .dclk   (rclk),
      .drst_n (rrst_n),
      .d_data (c_bank),
      .d_valid(c_valid)
  );

  // The MCP output c_bank (its d_data) is a registered value valid the cycle
  // AFTER c_valid (its d_valid strobe), so delay the strobe one cycle before
  // latching the completed-bank select.
  logic          c_valid_q;
  logic          rbank_q;
  logic          rvalid_q;
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      c_valid_q <= 1'b0;
      rbank_q   <= 1'b0;
      rvalid_q  <= 1'b0;
    end else begin
      c_valid_q <= c_valid;
      if (c_valid_q) begin
        rbank_q  <= c_bank;    // c_bank is now stable: the just-completed bank
        rvalid_q <= 1'b1;
      end else if (r_done) begin
        rvalid_q <= 1'b0;
      end
    end
  end
  assign r_valid = rvalid_q;
  assign r_bank  = rbank_q;

  assign rd_data = rbank_q ? mem1[rd_addr] : mem0[rd_addr];

  // Back-pressure: cross r_done to the write domain and track how many banks
  // the producer has handed over but the consumer has not yet released. With
  // two buffers only one may be outstanding, so the producer must wait
  // (w_ready low) before swapping a second time.
  logic done_event_w;
  cdc_sync_toggle u_done (
      .sclk    (rclk),
      .srst_n  (rrst_n),
      .s_pulse (r_done & rvalid_q),  // one event per consumed block
      .dclk    (wclk),
      .drst_n  (wrst_n),
      .d_pulse (done_event_w)
  );

  logic outstanding_q;   // 1 = a filled bank is in the consumer's hands
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      outstanding_q <= 1'b0;
    else begin
      case ({s_swap, done_event_w})
        2'b10: outstanding_q <= 1'b1;   // handed a bank over
        2'b01: outstanding_q <= 1'b0;   // consumer released one
        default: ;                       // both or neither: unchanged
      endcase
    end
  end
  assign w_ready = ~outstanding_q;

`ifdef FORMAL
  logic f_rpv = 1'b0;
  always_ff @(posedge rclk) begin
    if (!f_rpv) assume (!rrst_n);
    f_rpv <= 1'b1;
    // r_valid is only raised by a (delayed) bank-swap notification and cleared
    // by r_done: it never asserts spontaneously.
    if (f_rpv && rrst_n && $past(rrst_n) && !$past(rvalid_q) && !$past(c_valid_q))
      assert (!rvalid_q);
    if (rrst_n) cover (r_valid);
  end
  always_ff @(posedge wclk)
    if (wrst_n) cover (s_swap);
`endif

endmodule
