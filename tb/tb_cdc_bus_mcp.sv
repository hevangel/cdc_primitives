// tb_cdc_bus_mcp.sv — multi-cycle-path data transfer integrity.
`timescale 1ns/1ps
module tb_cdc_bus_mcp;
  localparam int WIDTH = 16;
  logic sclk = 0, srst_n = 0, s_load = 0;
  logic [WIDTH-1:0] s_data = 0;
  logic dclk = 0, drst_n = 0, d_valid;
  logic [WIDTH-1:0] d_data;
  always #5   sclk = ~sclk;
  always #3.3 dclk = ~dclk;

  cdc_bus_mcp #(.WIDTH(WIDTH)) dut (
      .sclk, .srst_n, .s_data, .s_load, .dclk, .drst_n, .d_data, .d_valid);

  logic [WIDTH-1:0] expected = 0;
  int errors = 0, loads = 0, caps = 0;

  // d_data is registered: valid the cycle AFTER the d_valid strobe.
  logic d_valid_q = 0;
  always_ff @(posedge dclk) d_valid_q <= drst_n && d_valid;

  always_ff @(posedge dclk)
    if (drst_n && d_valid_q) begin
      caps++;
      if (d_data !== expected) begin
        $display("DATA t=%0t got %0h exp %0h", $time, d_data, expected);
        errors++;
      end
    end

  initial begin
    srst_n = 0; drst_n = 0;
    repeat (4) @(posedge sclk); srst_n = 1; drst_n = 1;
    for (int i = 0; i < 12; i++) begin
      s_data = 16'h5500 + i; expected = s_data;
      @(posedge sclk) s_load = 1;
      @(posedge sclk) s_load = 0;
      loads++;
      repeat (8) @(posedge sclk);   // honour the MCP stability requirement
      repeat (2) @(posedge dclk);
    end
    repeat (10) @(posedge dclk);
    if (errors == 0 && caps == loads && loads == 12)
      $display("CDC cdc_bus_mcp PASS: %0d loads captured correctly across clocks", caps);
    else
      $display("CDC cdc_bus_mcp FAIL: errors=%0d loads=%0d caps=%0d", errors, loads, caps);
    $finish;
  end
endmodule
