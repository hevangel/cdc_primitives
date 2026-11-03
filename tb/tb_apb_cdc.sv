// tb_apb_cdc.sv — APB clock bridge: one transfer -> one completer access.
`timescale 1ns/1ps
module tb_apb_cdc;
  localparam int ADDR_W = 16, DATA_W = 32, STRB_W = DATA_W/8;
  // requester side
  logic rq_pclk = 0, rq_prstn = 0, rq_psel = 0, rq_penable = 0, rq_pwrite = 0;
  logic [ADDR_W-1:0] rq_paddr = 0; logic [DATA_W-1:0] rq_pwdata = 0; logic [STRB_W-1:0] rq_pstrb = '1;
  logic [DATA_W-1:0] rq_prdata; logic rq_pready, rq_pslverr;
  // completer side
  logic cp_pclk = 0, cp_prstn = 0, cp_psel, cp_penable, cp_pwrite;
  logic [ADDR_W-1:0] cp_paddr; logic [DATA_W-1:0] cp_pwdata; logic [STRB_W-1:0] cp_pstrb;
  logic [DATA_W-1:0] cp_prdata; logic cp_pready, cp_pslverr;
  always #5   rq_pclk = ~rq_pclk;
  always #3.7 cp_pclk = ~cp_pclk;

  apb_cdc #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
      .req_pclk(rq_pclk), .req_presetn(rq_prstn), .req_psel(rq_psel), .req_penable(rq_penable),
      .req_pwrite(rq_pwrite), .req_paddr(rq_paddr), .req_pwdata(rq_pwdata), .req_pstrb(rq_pstrb),
      .req_prdata(rq_prdata), .req_pready(rq_pready), .req_pslverr(rq_pslverr),
      .cmp_pclk(cp_pclk), .cmp_presetn(cp_prstn), .cmp_psel(cp_psel), .cmp_penable(cp_penable),
      .cmp_pwrite(cp_pwrite), .cmp_paddr(cp_paddr), .cmp_pwdata(cp_pwdata), .cmp_pstrb(cp_pstrb),
      .cmp_prdata(cp_prdata), .cmp_pready(cp_pready), .cmp_pslverr(cp_pslverr));

  int errors = 0, xfers = 0;

  // Simple completer model: 16-entry memory, zero-wait-state APB slave.
  // PRDATA is presented COMBINATIONALLY with PREADY in the ACCESS phase, as
  // the APB spec requires (read data valid on the PREADY cycle).
  logic [DATA_W-1:0] cmem [16];
  wire cp_access = cp_psel && cp_penable;
  assign cp_pready  = cp_access;                       // zero wait states
  assign cp_prdata  = cmem[cp_paddr[3:0]];             // combinational read
  assign cp_pslverr = 1'b0;
  always_ff @(posedge cp_pclk)
    if (cp_access && cp_pwrite) cmem[cp_paddr[3:0]] <= cp_pwdata;

  // One APB transfer helper on the requester side.
  task automatic apb_xfer(input logic wr, input logic [ADDR_W-1:0] a,
                          input logic [DATA_W-1:0] wd, output logic [DATA_W-1:0] rd);
    @(posedge rq_pclk);
    rq_psel = 1; rq_penable = 0; rq_pwrite = wr; rq_paddr = a; rq_pwdata = wd;
    @(posedge rq_pclk); rq_penable = 1;      // ACCESS phase
    do @(posedge rq_pclk); while (!rq_pready);
    rd = rq_prdata;
    rq_psel = 0; rq_penable = 0;
  endtask

  initial begin
    rq_prstn = 0; cp_prstn = 0;
    repeat (6) @(posedge rq_pclk); rq_prstn = 1; cp_prstn = 1;
    begin
      logic [DATA_W-1:0] rd;
      // Write a handful of locations, then read them back.
      for (int i = 0; i < 8; i++) begin apb_xfer(1'b1, i[ADDR_W-1:0], 32'hA5A50000 + i, rd); xfers++; end
      for (int i = 0; i < 8; i++) begin
        apb_xfer(1'b0, i[ADDR_W-1:0], 32'h0, rd); xfers++;
        if (rd !== (32'hA5A50000 + i)) begin $display("RB addr %0d got %08h exp %08h", i, rd, 32'hA5A50000+i); errors++; end
      end
    end
    if (errors == 0 && xfers == 16)
      $display("CDC apb_cdc PASS: %0d APB transfers bridged, read-back correct", xfers);
    else
      $display("CDC apb_cdc FAIL: errors=%0d xfers=%0d", errors, xfers);
    $finish;
  end

  initial begin #200000; $display("CDC apb_cdc FAIL: timeout"); $finish; end
endmodule
