// tb_rst_sync.sv — async assert, synchronous release.
`timescale 1ns/1ps
module tb_rst_sync;
  localparam int STAGES = 3;
  logic dclk = 0, raw_rst_n = 0, rst_n;
  always #5 dclk = ~dclk;

  rst_sync #(.STAGES(STAGES)) dut (.dclk, .raw_rst_n, .rst_n);

  int errors = 0;
  logic async_ok = 0, sync_ok = 0;

  initial begin
    // Start released, then assert: the falling edge triggers the async reset
    // (a FF modelled with `negedge raw_rst_n` needs the edge to clear).
    raw_rst_n = 1;
    #1 raw_rst_n = 0;
    #2;  // mid-cycle: async assert must already hold rst_n low
    if (rst_n === 1'b0) async_ok = 1; else errors++;
    repeat (3) @(posedge dclk);
    // Release raw reset; output must stay low for STAGES edges then rise.
    @(negedge dclk) raw_rst_n = 1;
    for (int i = 0; i < STAGES; i++) begin
      @(posedge dclk);
      if (i < STAGES-1 && rst_n !== 1'b0) errors++;   // still releasing
    end
    @(posedge dclk);
    if (rst_n === 1'b1) sync_ok = 1; else errors++;

    // Mid-cycle async re-assert.
    #1 raw_rst_n = 0; #1;
    if (rst_n !== 1'b0) errors++;

    if (errors == 0 && async_ok && sync_ok)
      $display("CDC rst_sync PASS: async assert, %0d-cycle synchronous release", STAGES);
    else
      $display("CDC rst_sync FAIL: errors=%0d async_ok=%0d sync_ok=%0d", errors, async_ok, sync_ok);
    $finish;
  end
endmodule
