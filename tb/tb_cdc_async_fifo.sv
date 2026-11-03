// tb_cdc_async_fifo.sv — dual-clock FIFO ordering, no overflow/underflow.
`timescale 1ns/1ps
module tb_cdc_async_fifo;
  localparam int WIDTH = 8, DEPTH = 8;
  logic wclk = 0, wrst_n = 0, wr_en = 0; logic [WIDTH-1:0] wr_data = 0; logic full;
  logic rclk = 0, rrst_n = 0, rd_en = 0; logic [WIDTH-1:0] rd_data; logic empty;
  always #5   wclk = ~wclk;   // 100 MHz write
  always #3.1 rclk = ~rclk;   // ~160 MHz read (faster reader)

  cdc_async_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
      .wclk, .wrst_n, .wr_en, .wr_data, .full,
      .rclk, .rrst_n, .rd_en, .rd_data, .empty);

  logic [WIDTH-1:0] q [$];
  int errors = 0, wrote = 0, read = 0;

  // Writer: push 64 words, respecting full.
  initial begin
    wrst_n = 0; repeat (4) @(posedge wclk); wrst_n = 1;
    for (int i = 0; i < 64; i++) begin
      @(posedge wclk);
      while (full) @(posedge wclk);
      wr_data = i[WIDTH-1:0]; wr_en = 1;
      q.push_back(wr_data); wrote++;
      @(posedge wclk) wr_en = 0;
    end
  end

  // Reader: when not empty, rd_data holds the head word; sample it, then
  // pulse rd_en for one cycle to advance the read pointer.
  initial begin
    rrst_n = 0; repeat (4) @(posedge rclk); rrst_n = 1;
    while (read < 64) begin
      @(posedge rclk);
      if (!empty) begin
        if (q.size() == 0) begin $display("UNDERRUN"); errors++; end
        else begin
          automatic logic [WIDTH-1:0] exp = q.pop_front();
          if (rd_data !== exp) begin $display("ORDER t=%0t got %0h exp %0h", $time, rd_data, exp); errors++; end
        end
        rd_en = 1;
        @(posedge rclk) rd_en = 0;
        read++;
      end
    end
    repeat (4) @(posedge rclk);
    if (errors == 0 && wrote >= 64 && read == 64)
      $display("CDC cdc_async_fifo PASS: 64 words FIFO-ordered, no overflow/underflow");
    else
      $display("CDC cdc_async_fifo FAIL: errors=%0d wrote=%0d read=%0d", errors, wrote, read);
    $finish;
  end
endmodule
