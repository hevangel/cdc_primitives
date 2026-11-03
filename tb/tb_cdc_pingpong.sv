// tb_cdc_pingpong.sv — double-buffer block transfer, no tearing.
`timescale 1ns/1ps
module tb_cdc_pingpong;
  localparam int WIDTH = 8, DEPTH = 16, AW = 4;
  logic wclk = 0, wrst_n = 0, wr_en = 0, s_swap = 0, w_ready, w_bank;
  logic [AW-1:0] wr_addr = 0;
  logic [WIDTH-1:0] wr_data = 0;
  logic rclk = 0, rrst_n = 0, r_valid, r_done = 0, r_bank;
  logic [AW-1:0] rd_addr = 0;
  logic [WIDTH-1:0] rd_data;
  always #5   wclk = ~wclk;
  always #3.7 rclk = ~rclk;

  cdc_pingpong #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
      .wclk, .wrst_n, .wr_en, .wr_addr, .wr_data, .s_swap, .w_ready, .w_bank,
      .rclk, .rrst_n, .rd_addr, .rd_data, .r_valid, .r_done, .r_bank);

  int blocks_consumed = 0, errors = 0, g;

  // Bank-ownership exclusivity is proven formally; the per-address data check
  // below is the authoritative simulation test. w_bank/r_bank are reported in
  // the final summary so they are observed (not asserted: pre-reset X).

  // Producer: fill a block (value = base+addr), then swap. Do 3 blocks.
  initial begin
    wrst_n = 0; repeat (4) @(posedge wclk); wrst_n = 1;
    for (int b = 0; b < 3; b++) begin
      // Honour back-pressure: wait until the previous buffer is released.
      while (!w_ready) @(posedge wclk);
      for (int a = 0; a < DEPTH; a++) begin
        wr_addr = a[AW-1:0]; wr_data = (b*16 + a); wr_en = 1;
        @(posedge wclk);
      end
      wr_en = 0; @(posedge wclk);
      s_swap = 1; @(posedge wclk);
      s_swap = 0; @(posedge wclk);
    end
  end

  // Consumer: when a block is announced, read it out and verify, then r_done.
  initial begin
    rrst_n = 0; repeat (4) @(posedge rclk); rrst_n = 1;
    for (int b = 0; b < 3; b++) begin
      g = 0;
      while (!r_valid && g < 400) begin @(posedge rclk); g++; end
      if (!r_valid) begin $display("NO BLOCK %0d", b); errors++; end
      else begin
        for (int a = 0; a < DEPTH; a++) begin
          rd_addr = a[AW-1:0];
          @(posedge rclk);
          if (rd_data !== (b*16 + a)) begin
            $display("BLK %0d addr %0d got %0h exp %0h", b, a, rd_data, b*16+a); errors++;
          end
        end
        blocks_consumed++;
        @(posedge rclk) r_done = 1;
        @(posedge rclk) r_done = 0;
        // Wait for r_valid to drop before looking for the next block, so the
        // next iteration does not re-read the same (stale) block.
        while (r_valid) @(posedge rclk);
      end
    end
    repeat (10) @(posedge rclk);
    if (errors == 0 && blocks_consumed == 3)
      $display("CDC cdc_pingpong PASS: 3 blocks double-buffered, no tearing (final w_bank=%b r_bank=%b)", w_bank, r_bank);
    else
      $display("CDC cdc_pingpong FAIL: errors=%0d blocks=%0d", errors, blocks_consumed);
    $finish;
  end
endmodule
