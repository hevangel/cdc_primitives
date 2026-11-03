// tb_cdc_bus_handshake.sv — in-order, lossless, uncorrupted data transfer.
`timescale 1ns/1ps
module tb_cdc_bus_handshake;
  localparam int WIDTH = 16;
  logic sclk = 0, srst_n = 0, s_valid = 0, s_ready;
  logic [WIDTH-1:0] s_data = 0;
  logic dclk = 0, drst_n = 0, d_valid, d_ready = 1;
  logic [WIDTH-1:0] d_data;
  always #5   sclk = ~sclk;
  always #3.7 dclk = ~dclk;

  cdc_bus_handshake #(.WIDTH(WIDTH)) dut (
      .sclk, .srst_n, .s_data, .s_valid, .s_ready,
      .dclk, .drst_n, .d_data, .d_valid, .d_ready);

  // Reference queue of expected words, in order.
  logic [WIDTH-1:0] q [$];
  int errors = 0, recv = 0, sent = 0;

  always_ff @(posedge sclk)
    if (srst_n && s_valid && s_ready) begin q.push_back(s_data); sent++; end

  // d_data is a registered output: it carries the delivered word the cycle
  // AFTER the d_valid strobe. Delay the check by one cycle so d_data is valid.
  logic d_valid_q = 0;
  always_ff @(posedge dclk) d_valid_q <= drst_n && d_valid;

  always_ff @(posedge dclk)
    if (drst_n && d_valid_q) begin
      recv++;
      if (q.size() == 0) begin $display("UNDERRUN"); errors++; end
      else begin
        automatic logic [WIDTH-1:0] exp = q.pop_front();
        if (d_data !== exp) begin $display("DATA t=%0t got %0h exp %0h", $time, d_data, exp); errors++; end
      end
    end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 20; i++) begin
      @(posedge sclk);
      while (!s_ready) @(posedge sclk);
      s_data = 16'hA000 + i; s_valid = 1;
      @(posedge sclk) s_valid = 0;
      repeat (2) @(posedge sclk);
    end
    repeat (40) @(posedge dclk);
    if (errors == 0 && sent == recv && sent == 20)
      $display("CDC cdc_bus_handshake PASS: %0d words transferred in order, uncorrupted", recv);
    else
      $display("CDC cdc_bus_handshake FAIL: errors=%0d sent=%0d recv=%0d", errors, sent, recv);
    $finish;
  end
endmodule
