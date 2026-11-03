// tb_cdc_snapshot.sv — coherent multi-field snapshot transfer.
`timescale 1ns/1ps
module tb_cdc_snapshot;
  localparam int WIDTH = 32;
  logic sclk = 0, srst_n = 0, s_capture = 0;
  logic [WIDTH-1:0] s_vector = 0;
  logic dclk = 0, drst_n = 0, d_valid;
  logic [WIDTH-1:0] d_vector;
  always #5   sclk = ~sclk;
  always #3.7 dclk = ~dclk;

  cdc_snapshot #(.WIDTH(WIDTH)) dut (
      .sclk, .srst_n, .s_vector, .s_capture, .dclk, .drst_n, .d_vector, .d_valid);

  logic [WIDTH-1:0] expect_vec = 0;
  int errors = 0, snaps = 0;

  // d_vector is registered: valid the cycle AFTER the d_valid strobe.
  logic d_valid_q = 0;
  always_ff @(posedge dclk) d_valid_q <= drst_n && d_valid;

  always_ff @(posedge dclk)
    if (drst_n && d_valid_q) begin
      snaps++;
      // Two fields must be mutually consistent (lo = ~hi) — no tearing.
      if (d_vector[15:0] !== ~d_vector[31:16]) begin
        $display("TEAR t=%0t vec=%08h", $time, d_vector); errors++;
      end
      if (d_vector !== expect_vec) begin
        $display("DATA t=%0t got %08h exp %08h", $time, d_vector, expect_vec); errors++;
      end
    end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 8; i++) begin
      logic [15:0] lo = 16'h1000 + i;
      s_vector = {~lo, lo};  expect_vec = s_vector;   // coherent pair
      @(posedge sclk) s_capture = 1;
      @(posedge sclk) s_capture = 0;
      repeat (8) @(posedge sclk);
      repeat (2) @(posedge dclk);
    end
    repeat (10) @(posedge dclk);
    if (errors == 0 && snaps == 8)
      $display("CDC cdc_snapshot PASS: %0d coherent snapshots, no tearing", snaps);
    else
      $display("CDC cdc_snapshot FAIL: errors=%0d snaps=%0d", errors, snaps);
    $finish;
  end
endmodule
