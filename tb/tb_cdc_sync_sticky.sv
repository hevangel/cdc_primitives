// tb_cdc_sync_sticky.sv — sticky status captured and cleared across clocks.
`timescale 1ns/1ps
module tb_cdc_sync_sticky;
  logic sclk = 0, srst_n = 0, s_set = 0;
  logic dclk = 0, drst_n = 0, d_clear = 0, d_status;
  always #7   sclk = ~sclk;   // slow source
  always #3.1 dclk = ~dclk;   // fast destination

  cdc_sync_sticky dut (.sclk, .srst_n, .s_set, .dclk, .drst_n, .d_clear, .d_status);

  bit captured = 0, cleared = 0;
  int g;

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;

    // Emit a single-cycle source event (too narrow for a naive 2FF at this
    // ratio) and confirm the destination latches it.
    @(posedge sclk) s_set = 1;
    @(posedge sclk) s_set = 0;
    g = 0;
    while (!d_status && g < 100) begin @(posedge dclk); g++; end
    if (d_status) captured = 1;

    // Clear it from the destination.
    @(posedge dclk) d_clear = 1;
    @(posedge dclk) d_clear = 0;
    g = 0;
    while (d_status && g < 100) begin @(posedge dclk); g++; end
    if (!d_status) cleared = 1;

    if (captured && cleared)
      $display("CDC cdc_sync_sticky PASS: narrow event captured and cleared across clocks");
    else
      $display("CDC cdc_sync_sticky FAIL: captured=%0d cleared=%0d", captured, cleared);
    $finish;
  end
endmodule
