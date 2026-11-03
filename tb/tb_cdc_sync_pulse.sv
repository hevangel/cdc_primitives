// tb_cdc_sync_pulse.sv — pulse recovery with stretch width check.
`timescale 1ns/1ps
module tb_cdc_sync_pulse;
  localparam int W = 4;
  logic sclk = 0, srst_n = 0, s_pulse = 0;
  logic dclk = 0, drst_n = 0, d_pulse;
  always #5   sclk = ~sclk;
  always #3.3 dclk = ~dclk;

  cdc_sync_pulse #(.DST_WIDTH(W)) dut (.sclk, .srst_n, .s_pulse, .dclk, .drst_n, .d_pulse);

  int events = 0, maxrun = 0, run = 0;
  always_ff @(posedge dclk) begin
    if (!drst_n) begin run <= 0; end
    else if (d_pulse) begin
      run <= run + 1;
      if (run + 1 > maxrun) maxrun <= run + 1;
    end else begin
      if (run > 0) events <= events + 1;
      run <= 0;
    end
  end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 6; i++) begin
      @(posedge sclk) s_pulse = 1;
      @(posedge sclk) s_pulse = 0;
      repeat (12) @(posedge sclk);
    end
    repeat (20) @(posedge dclk);
    if (events == 6 && maxrun == W)
      $display("CDC cdc_sync_pulse PASS: %0d pulses, stretched to %0d dclk cycles", events, maxrun);
    else
      $display("CDC cdc_sync_pulse FAIL: events=%0d maxrun=%0d (want 6/%0d)", events, maxrun, W);
    $finish;
  end
endmodule
