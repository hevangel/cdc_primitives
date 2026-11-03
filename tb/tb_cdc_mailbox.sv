// tb_cdc_mailbox.sv — one-deep message passing, lossless with backpressure.
`timescale 1ns/1ps
module tb_cdc_mailbox;
  localparam int WIDTH = 16;
  logic sclk = 0, srst_n = 0, s_wr = 0, s_full;
  logic [WIDTH-1:0] s_msg = 0;
  logic dclk = 0, drst_n = 0, d_wr, d_rd = 0;
  logic [WIDTH-1:0] d_msg;
  always #5   sclk = ~sclk;
  always #3.3 dclk = ~dclk;

  cdc_mailbox #(.WIDTH(WIDTH)) dut (
      .sclk, .srst_n, .s_msg, .s_wr, .s_full, .dclk, .drst_n, .d_msg, .d_wr, .d_rd);

  logic [WIDTH-1:0] q [$];
  int errors = 0, sent = 0, recv = 0;

  // d_msg is registered: valid the cycle AFTER the d_wr strobe. Check on the
  // delayed strobe; release the mailbox with d_rd on the strobe itself.
  logic d_wr_q = 0;
  always_ff @(posedge dclk) begin
    d_wr_q <= drst_n && d_wr;
    d_rd   <= drst_n && d_wr;    // consume (release) on delivery
  end

  always_ff @(posedge dclk)
    if (drst_n && d_wr_q) begin
      recv++;
      if (q.size()==0) begin $display("UNDERRUN"); errors++; end
      else begin
        automatic logic [WIDTH-1:0] e = q.pop_front();
        if (d_msg !== e) begin $display("MSG got %0h exp %0h", d_msg, e); errors++; end
      end
    end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 10; i++) begin
      @(posedge sclk);
      while (s_full) @(posedge sclk);
      s_msg = 16'hC000 + i; s_wr = 1; q.push_back(s_msg); sent++;
      @(posedge sclk) s_wr = 0;
      repeat (2) @(posedge sclk);
    end
    repeat (40) @(posedge dclk);
    if (errors == 0 && sent == recv && sent == 10)
      $display("CDC cdc_mailbox PASS: %0d messages delivered in order, lossless", recv);
    else
      $display("CDC cdc_mailbox FAIL: errors=%0d sent=%0d recv=%0d", errors, sent, recv);
    $finish;
  end
endmodule
