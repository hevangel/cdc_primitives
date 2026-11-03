// cdc_mailbox.sv — single-message mailbox across clock domains (covers C7)
//
// A one-deep message channel: the source writes a message word, the
// destination reads it, and the slot cannot be overwritten until the
// destination has consumed it. Built on the full req/ack bus handshake, so it
// is lossless with backpressure — the natural primitive for CPU <-> firmware
// command passing.
//
// Contract
//   Clock assumptions : sclk and dclk asynchronous.
//   Data assumptions  : ready/valid on both sides.
//   Guarantees        : exactly one delivery per accepted message, in order,
//                       uncorrupted; source blocked (s_ready low) until the
//                       message is consumed.
//   Reset             : either reset returns the mailbox to empty.
module cdc_mailbox #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             sclk,
    input  logic             srst_n,
    input  logic [WIDTH-1:0] s_msg,
    input  logic             s_wr,     // write a message
    output logic             s_full,   // mailbox cannot accept a message

    input  logic             dclk,
    input  logic             drst_n,
    output logic [WIDTH-1:0] d_msg,
    output logic             d_wr,     // a message is available (1 cycle)
    input  logic             d_rd      // destination consumed the message
);

  logic s_ready;
  assign s_full = !s_ready;

  cdc_bus_handshake #(.WIDTH(WIDTH)) u_hs (
      .sclk   (sclk),
      .srst_n (srst_n),
      .s_data (s_msg),
      .s_valid(s_wr),
      .s_ready(s_ready),
      .dclk   (dclk),
      .drst_n (drst_n),
      .d_data (d_msg),
      .d_valid(d_wr),
      .d_ready(d_rd)
  );

`ifdef FORMAL
  always_ff @(posedge dclk) if (drst_n) cover (d_wr);
  always_ff @(posedge sclk) if (srst_n) assert (s_full == !s_ready);
`endif

endmodule
