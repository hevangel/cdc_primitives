// tb_cdc_event_counter.sv — lossless event accumulation across clocks.
`timescale 1ns/1ps
module tb_cdc_event_counter;
  localparam int WIDTH = 12;
  logic sclk = 0, srst_n = 0, s_event = 0;
  logic dclk = 0, drst_n = 0;
  logic [WIDTH-1:0] d_count;
  always #5   sclk = ~sclk;
  always #3.3 dclk = ~dclk;

  cdc_event_counter #(.WIDTH(WIDTH)) dut (.sclk, .srst_n, .s_event, .dclk, .drst_n, .d_count);

  int sent = 0;

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 150; i++) begin
      @(posedge sclk);
      s_event = 1'($urandom);
      if (s_event) sent++;
    end
    @(posedge sclk) s_event = 0;
    repeat (10) @(posedge dclk);
    // The destination count must have caught up to the exact source total.
    if (d_count == sent[WIDTH-1:0])
      $display("CDC cdc_event_counter PASS: %0d events, d_count=%0d (no loss)", sent, d_count);
    else
      $display("CDC cdc_event_counter FAIL: sent=%0d d_count=%0d", sent, d_count);
    $finish;
  end
endmodule
