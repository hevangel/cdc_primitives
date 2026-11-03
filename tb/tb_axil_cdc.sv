// tb_axil_cdc.sv — AXI4-Lite clock converter: writes + reads across clocks.
`timescale 1ns/1ps
module tb_axil_cdc;
  localparam int ADDR_W = 32, DATA_W = 32, STRB_W = DATA_W/8, DEPTH = 4;
  // slave port (master clock)
  logic sclk = 0, srstn = 0;
  logic [ADDR_W-1:0] s_awaddr=0; logic [2:0] s_awprot=0; logic s_awvalid=0, s_awready;
  logic [DATA_W-1:0] s_wdata=0; logic [STRB_W-1:0] s_wstrb='1; logic s_wvalid=0, s_wready;
  logic [1:0] s_bresp; logic s_bvalid, s_bready=0;
  logic [ADDR_W-1:0] s_araddr=0; logic [2:0] s_arprot=0; logic s_arvalid=0, s_arready;
  logic [DATA_W-1:0] s_rdata; logic [1:0] s_rresp; logic s_rvalid, s_rready=0;
  // master port (slave clock)
  logic mclk = 0, mrstn = 0;
  logic [ADDR_W-1:0] m_awaddr; logic [2:0] m_awprot; logic m_awvalid, m_awready=0;
  logic [DATA_W-1:0] m_wdata; logic [STRB_W-1:0] m_wstrb; logic m_wvalid, m_wready=0;
  logic [1:0] m_bresp=0; logic m_bvalid=0, m_bready;
  logic [ADDR_W-1:0] m_araddr; logic [2:0] m_arprot; logic m_arvalid, m_arready=0;
  logic [DATA_W-1:0] m_rdata=0; logic [1:0] m_rresp=0; logic m_rvalid=0, m_rready;
  always #5   sclk = ~sclk;
  always #3.3 mclk = ~mclk;

  axil_cdc #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(DEPTH)) dut (
    .s_axil_aclk(sclk), .s_axil_arstn(srstn),
    .s_axil_awaddr(s_awaddr), .s_axil_awprot(s_awprot), .s_axil_awvalid(s_awvalid), .s_axil_awready(s_awready),
    .s_axil_wdata(s_wdata), .s_axil_wstrb(s_wstrb), .s_axil_wvalid(s_wvalid), .s_axil_wready(s_wready),
    .s_axil_bresp(s_bresp), .s_axil_bvalid(s_bvalid), .s_axil_bready(s_bready),
    .s_axil_araddr(s_araddr), .s_axil_arprot(s_arprot), .s_axil_arvalid(s_arvalid), .s_axil_arready(s_arready),
    .s_axil_rdata(s_rdata), .s_axil_rresp(s_rresp), .s_axil_rvalid(s_rvalid), .s_axil_rready(s_rready),
    .m_axil_aclk(mclk), .m_axil_arstn(mrstn),
    .m_axil_awaddr(m_awaddr), .m_axil_awprot(m_awprot), .m_axil_awvalid(m_awvalid), .m_axil_awready(m_awready),
    .m_axil_wdata(m_wdata), .m_axil_wstrb(m_wstrb), .m_axil_wvalid(m_wvalid), .m_axil_wready(m_wready),
    .m_axil_bresp(m_bresp), .m_axil_bvalid(m_bvalid), .m_axil_bready(m_bready),
    .m_axil_araddr(m_araddr), .m_axil_arprot(m_arprot), .m_axil_arvalid(m_arvalid), .m_axil_arready(m_arready),
    .m_axil_rdata(m_rdata), .m_axil_rresp(m_rresp), .m_axil_rvalid(m_rvalid), .m_axil_rready(m_rready));

  int errors = 0, writes = 0, reads = 0;
  logic [DATA_W-1:0] mem [16];

  // -------- downstream AXI-Lite slave model (master clock) --------
  // Write: accept AW and W, then issue B.
  logic [ADDR_W-1:0] aw_a; logic aw_seen, w_seen;
  always_ff @(posedge mclk or negedge mrstn) begin
    if (!mrstn) begin
      m_awready<=0; m_wready<=0; m_bvalid<=0; m_bresp<=0; aw_seen<=0; w_seen<=0; aw_a<=0;
    end else begin
      m_awready<=0; m_wready<=0;
      if (m_awvalid && !aw_seen) begin aw_a<=m_awaddr; aw_seen<=1; m_awready<=1; end
      if (m_wvalid && !w_seen) begin w_seen<=1; m_wready<=1; mem[aw_seen?aw_a[5:2]:m_awaddr[5:2]]<=m_wdata; end
      if (aw_seen && w_seen && !m_bvalid) begin m_bvalid<=1; m_bresp<=2'b00; end
      if (m_bvalid && m_bready) begin m_bvalid<=0; aw_seen<=0; w_seen<=0; end
    end
  end
  // Read: accept AR, then issue R.
  logic [ADDR_W-1:0] ar_a; logic ar_seen;
  always_ff @(posedge mclk or negedge mrstn) begin
    if (!mrstn) begin m_arready<=0; m_rvalid<=0; m_rdata<=0; m_rresp<=0; ar_seen<=0; ar_a<=0; end
    else begin
      m_arready<=0;
      if (m_arvalid && !ar_seen) begin ar_a<=m_araddr; ar_seen<=1; m_arready<=1; end
      if (ar_seen && !m_rvalid) begin m_rvalid<=1; m_rdata<=mem[ar_a[5:2]]; m_rresp<=2'b00; end
      if (m_rvalid && m_rready) begin m_rvalid<=0; ar_seen<=0; end
    end
  end

  // -------- upstream master tasks (slave clock) --------
  task automatic axil_write(input logic [ADDR_W-1:0] a, input logic [DATA_W-1:0] d);
    fork
      begin @(posedge sclk); s_awaddr=a; s_awvalid=1; do @(posedge sclk); while(!s_awready); s_awvalid=0; end
      begin @(posedge sclk); s_wdata=d; s_wvalid=1; do @(posedge sclk); while(!s_wready); s_wvalid=0; end
    join
    s_bready=1; do @(posedge sclk); while(!s_bvalid); s_bready=0;
  endtask
  task automatic axil_read(input logic [ADDR_W-1:0] a, output logic [DATA_W-1:0] d);
    @(posedge sclk); s_araddr=a; s_arvalid=1; do @(posedge sclk); while(!s_arready); s_arvalid=0;
    s_rready=1; do @(posedge sclk); while(!s_rvalid); d=s_rdata; s_rready=0;
  endtask

  initial begin
    srstn=0; mrstn=0; repeat (8) @(posedge sclk); srstn=1; mrstn=1;
    begin
      logic [DATA_W-1:0] rd;
      for (int i=0;i<8;i++) begin axil_write(i*4, 32'hC0DE0000 + i); writes++; end
      for (int i=0;i<8;i++) begin
        axil_read(i*4, rd); reads++;
        if (rd !== (32'hC0DE0000 + i)) begin $display("RB %0d got %08h exp %08h", i, rd, 32'hC0DE0000+i); errors++; end
      end
    end
    if (errors==0 && writes==8 && reads==8)
      $display("CDC axil_cdc PASS: 8 writes + 8 reads bridged across clocks, read-back correct");
    else
      $display("CDC axil_cdc FAIL: errors=%0d writes=%0d reads=%0d", errors, writes, reads);
    $finish;
  end
  initial begin #500000; $display("CDC axil_cdc FAIL: timeout"); $finish; end
endmodule
