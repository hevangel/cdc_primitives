// tb_cdc_sync_event_handshake.sv — lossless back-pressured events.
`timescale 1ns/1ps
module tb_cdc_sync_event_handshake;
  logic sclk = 0, srst_n = 0, s_valid = 0, s_ready;
  logic dclk = 0, drst_n = 0, d_event;
  always #5   sclk = ~sclk;
  always #3.7 dclk = ~dclk;

  cdc_sync_event_handshake dut (.sclk, .srst_n, .s_valid, .s_ready, .dclk, .drst_n, .d_event);

  int sent = 0, recv = 0;
  always_ff @(posedge sclk) if (srst_n && s_valid && s_ready) sent++;
  always_ff @(posedge dclk) if (drst_n && d_event) recv++;

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    // Keep requesting; the channel back-pressures via s_ready.
    for (int i = 0; i < 300; i++) begin
      @(posedge sclk);
      s_valid = (i < 250) ? 1'b1 : 1'b0;   // request for a while, then idle
    end
    repeat (30) @(posedge dclk);
    // Every accepted request must be delivered exactly once.
    if (sent == recv && sent > 0)
      $display("CDC cdc_sync_event_handshake PASS: %0d events sent and delivered (lossless)", sent);
    else
      $display("CDC cdc_sync_event_handshake FAIL: sent=%0d recv=%0d", sent, recv);
    $finish;
  end
endmodule
