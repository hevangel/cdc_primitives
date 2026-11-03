// tb_cdc_sync_toggle.sv — event count preservation across clocks.
`timescale 1ns/1ps
module tb_cdc_sync_toggle;
  logic sclk = 0, srst_n = 0, s_pulse = 0;
  logic dclk = 0, drst_n = 0, d_pulse;
  always #5    sclk = ~sclk;   // 100 MHz source
  always #3.3  dclk = ~dclk;   // ~150 MHz destination (asynchronous)

  cdc_sync_toggle dut (.sclk, .srst_n, .s_pulse, .dclk, .drst_n, .d_pulse);

  int sent = 0, recv = 0;
  always_ff @(posedge sclk) if (srst_n && s_pulse) sent++;
  always_ff @(posedge dclk) if (drst_n && d_pulse) recv++;

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    // Generate well-spaced source events (spacing >> sync latency).
    for (int i = 0; i < 10; i++) begin
      @(posedge sclk) s_pulse = 1;
      @(posedge sclk) s_pulse = 0;
      repeat (6) @(posedge sclk);   // let the toggle settle on both sides
    end
    repeat (20) @(posedge dclk);
    if (sent == recv && sent == 10)
      $display("CDC cdc_sync_toggle PASS: %0d events sent, %0d recovered", sent, recv);
    else
      $display("CDC cdc_sync_toggle FAIL: sent=%0d recv=%0d", sent, recv);
    $finish;
  end
endmodule
