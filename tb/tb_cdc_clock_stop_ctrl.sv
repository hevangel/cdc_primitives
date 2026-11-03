// tb_cdc_clock_stop_ctrl.sv — clock stop/start handshake with isolation.
`timescale 1ns/1ps
module tb_cdc_clock_stop_ctrl;
  logic ctrl_clk = 0, ctrl_rst_n = 0, stop_req = 0, stopped;
  logic tgt_clk  = 0, tgt_rst_n  = 0, tgt_idle = 0, clk_en, isolate;
  always #5   ctrl_clk = ~ctrl_clk;
  always #3.7 tgt_clk  = ~tgt_clk;

  cdc_clock_stop_ctrl dut (
      .ctrl_clk, .ctrl_rst_n, .stop_req, .stopped,
      .tgt_clk, .tgt_rst_n, .tgt_idle, .clk_en, .isolate);

  int errors = 0, g;
  bit saw_stop = 0, saw_restart = 0;

  // Safety monitor: whenever the clock is gated off, outputs must be isolated.
  // (clk_en is a known 0/1 value once reset has been applied.)
  always_ff @(posedge ctrl_clk)
    if (ctrl_rst_n && (clk_en === 1'b0) && !isolate) errors++;

  initial begin
    ctrl_rst_n = 0; tgt_rst_n = 0; tgt_idle = 1;
    repeat (4) @(posedge ctrl_clk); ctrl_rst_n = 1; tgt_rst_n = 1;

    // Request a stop; target is idle so it should grant. Wait until the clock
    // is actually gated off (clk_en drops one cycle after `stopped` rises).
    @(posedge ctrl_clk) stop_req = 1;
    g = 0; while (clk_en && g < 200) begin @(posedge ctrl_clk); g++; end
    if (stopped && !clk_en && isolate) saw_stop = 1; else errors++;

    // Release the stop; the clock should restart and deisolate.
    @(posedge ctrl_clk) stop_req = 0;
    g = 0; while (!clk_en && g < 200) begin @(posedge ctrl_clk); g++; end
    if (clk_en && !isolate && !stopped) saw_restart = 1; else errors++;

    if (errors == 0 && saw_stop && saw_restart)
      $display("CDC cdc_clock_stop_ctrl PASS: stop granted (isolated), restart clean");
    else
      $display("CDC cdc_clock_stop_ctrl FAIL: errors=%0d stop=%0d restart=%0d", errors, saw_stop, saw_restart);
    $finish;
  end
endmodule
