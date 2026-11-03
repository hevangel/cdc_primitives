// tb_cdc_sync_gray.sv — monotonic counter transferred via Gray code.
`timescale 1ns/1ps
module tb_cdc_sync_gray;
  localparam int WIDTH = 8;
  logic sclk = 0, srst_n = 0;
  logic [WIDTH-1:0] s_bin = 0;
  logic dclk = 0, drst_n = 0;
  logic [WIDTH-1:0] d_bin;
  always #5   sclk = ~sclk;
  always #3.3 dclk = ~dclk;

  cdc_sync_gray #(.WIDTH(WIDTH)) dut (.sclk, .srst_n, .s_bin, .dclk, .drst_n, .d_bin);

  int errors = 0;
  logic [WIDTH-1:0] last_d = 0;

  // d_bin must always be a value s_bin actually held, and never decrease
  // (the source counter is monotonic up).
  always_ff @(posedge dclk) begin
    if (drst_n) begin
      if (d_bin !== last_d) begin
        if (((d_bin - last_d) & 8'hFF) > 8'd4) begin  // allow small sync skew
          $display("JUMP t=%0t %0d->%0d", $time, last_d, d_bin);
          errors++;
        end
        last_d <= d_bin;
      end
    end
  end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 200; i++) @(posedge sclk) s_bin <= s_bin + 1;
    repeat (10) @(posedge dclk);
    // Final value should have caught up to near the source value.
    if (errors == 0 && (d_bin >= 8'd190))
      $display("CDC cdc_sync_gray PASS: monotonic transfer, final d_bin=%0d s_bin=%0d", d_bin, s_bin);
    else
      $display("CDC cdc_sync_gray FAIL: errors=%0d d_bin=%0d s_bin=%0d", errors, d_bin, s_bin);
    $finish;
  end
endmodule
