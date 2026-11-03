// tb_cdc_sync_bit.sv — two-clock self-checking testbench for cdc_sync_bit.
`timescale 1ns/1ps
module tb_cdc_sync_bit;
  logic dclk = 0, drst_n = 0, din = 0, dout;
  // Destination clock ~ 130 MHz (asynchronous to the stimulus timing).
  always #3.8 dclk = ~dclk;

  cdc_sync_bit #(.STAGES(3)) dut (.dclk, .drst_n, .din, .dout);

  int errors = 0;

  // Reference: a software shift register sampled on dclk.
  logic [2:0] ref_sr = 0;
  always_ff @(posedge dclk or negedge drst_n)
    if (!drst_n) ref_sr <= 0; else ref_sr <= {ref_sr[1:0], din};

  always_ff @(posedge dclk)
    if (drst_n && (dout !== ref_sr[2])) begin
      $display("MISMATCH t=%0t dout=%b ref=%b", $time, dout, ref_sr[2]);
      errors++;
    end

  initial begin
    drst_n = 0; repeat (4) @(posedge dclk);
    drst_n = 1;
    // Drive din asynchronously relative to dclk.
    for (int i = 0; i < 40; i++) begin
      #2.7 din = 1'($urandom);
    end
    repeat (6) @(posedge dclk);
    if (errors == 0) $display("CDC cdc_sync_bit PASS: %0d cycles, output tracks 3-FF delay", 40);
    else             $display("CDC cdc_sync_bit FAIL: %0d mismatches", errors);
    $finish;
  end
endmodule
