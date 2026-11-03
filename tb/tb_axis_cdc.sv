// tb_axis_cdc.sv — AXI-Stream clock converter: lossless, in-order beats.
`timescale 1ns/1ps
module tb_axis_cdc;
  localparam int DATA_W = 32, DEPTH = 8, KEEP_W = DATA_W/8;
  logic s_aclk = 0, s_arstn = 0;
  logic [DATA_W-1:0]   s_tdata = 0; logic [KEEP_W-1:0] s_tkeep = '1;
  logic                s_tlast = 0, s_tid = 0, s_tvalid = 0, s_tready;
  logic m_aclk = 0, m_arstn = 0;
  logic [DATA_W-1:0]   m_tdata; logic [KEEP_W-1:0] m_tkeep;
  logic                m_tlast, m_tid, m_tvalid, m_tready = 0;
  always #5   s_aclk = ~s_aclk;   // 100 MHz
  always #3.3 m_aclk = ~m_aclk;   // ~150 MHz (asynchronous)

  axis_cdc #(.DATA_W(DATA_W), .ID_W(0), .DEPTH(DEPTH)) dut (
      .s_axis_aclk(s_aclk), .s_axis_arstn(s_arstn),
      .s_axis_tdata(s_tdata), .s_axis_tkeep(s_tkeep), .s_axis_tlast(s_tlast),
      .s_axis_tid(s_tid), .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready),
      .m_axis_aclk(m_aclk), .m_axis_arstn(m_arstn),
      .m_axis_tdata(m_tdata), .m_axis_tkeep(m_tkeep), .m_axis_tlast(m_tlast),
      .m_axis_tid(m_tid), .m_axis_tvalid(m_tvalid), .m_axis_tready(m_tready));

  logic [DATA_W-1:0] q [$];
  int errors = 0, sent = 0, recv = 0;

  always_ff @(posedge s_aclk)
    if (s_arstn && s_tvalid && s_tready) begin q.push_back(s_tdata); sent++; end

  always_ff @(posedge m_aclk)
    if (m_arstn && m_tvalid && m_tready) begin
      recv++;
      if (q.size()==0) begin $display("UNDERRUN"); errors++; end
      else begin
        automatic logic [DATA_W-1:0] e = q.pop_front();
        if (m_tdata !== e) begin $display("DATA got %08h exp %08h", m_tdata, e); errors++; end
      end
    end

  // Master accepts with gaps to exercise backpressure.
  initial begin
    m_arstn = 0; repeat (6) @(posedge m_aclk); m_arstn = 1;
    forever begin @(posedge m_aclk); m_tready = $urandom & 1; end
  end

  initial begin
    s_arstn = 0; repeat (6) @(posedge s_aclk); s_arstn = 1;
    for (int i = 0; i < 40; i++) begin
      @(posedge s_aclk);
      while (!s_tready) @(posedge s_aclk);
      s_tdata = 32'hBEEF_0000 + i; s_tlast = (i % 8 == 7); s_tvalid = 1;
      @(posedge s_aclk) s_tvalid = 0;
    end
    repeat (120) @(posedge m_aclk);
    if (errors == 0 && sent == recv && sent == 40)
      $display("CDC axis_cdc PASS: %0d beats transferred in order, uncorrupted", recv);
    else
      $display("CDC axis_cdc FAIL: errors=%0d sent=%0d recv=%0d", errors, sent, recv);
    $finish;
  end
endmodule
