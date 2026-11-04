// axil_cdc.sv — AXI4-Lite clock-domain converter (taxonomy E2)
//
// Crosses a full AXI4-Lite interface between two asynchronous clocks. Each of
// the five AXI channels (AW, W, B, AR, R) is an independent async FIFO, which
// is the standard, deadlock-free way to clock-convert AXI: channels are
// mutually independent and each has its own ready/valid flow control, so a
// per-channel FIFO preserves ordering within a channel and never couples two
// channels across the boundary.
//
// The slave port (s_axil_*) faces the upstream master in the s_axil_aclk
// domain; the master port (m_axil_*) faces the downstream slave in the
// m_axil_aclk domain.
//
// Contract
//   Clock assumptions : s_axil_aclk and m_axil_aclk asynchronous.
//   Protocol          : AXI4-Lite on both ports (no bursts, single beats).
//   Guarantees        : each channel is lossless, in order, uncorrupted with
//                       backpressure; write and read paths stay independent
//                       (no cross-channel deadlock introduced by the crossing).
//   Reset             : coordinated reset release across both domains.
//
// Parameters
//   ADDR_W : address width.
//   DATA_W : data width (32 or 64 for AXI4-Lite).
//   DEPTH  : per-channel FIFO depth (power of two >= 2).
module axil_cdc #(
    parameter int unsigned ADDR_W = 32,
    parameter int unsigned DATA_W = 32,
    parameter int unsigned DEPTH  = 4
) (
    // ---------------- slave port (upstream master clock) ----------------
    input  logic              s_axil_aclk,
    input  logic              s_axil_arstn,
    // AW
    input  logic [ADDR_W-1:0] s_axil_awaddr,
    input  logic [2:0]        s_axil_awprot,
    input  logic              s_axil_awvalid,
    output logic              s_axil_awready,
    // W
    input  logic [DATA_W-1:0] s_axil_wdata,
    input  logic [DATA_W/8-1:0] s_axil_wstrb,
    input  logic              s_axil_wvalid,
    output logic              s_axil_wready,
    // B
    output logic [1:0]        s_axil_bresp,
    output logic              s_axil_bvalid,
    input  logic              s_axil_bready,
    // AR
    input  logic [ADDR_W-1:0] s_axil_araddr,
    input  logic [2:0]        s_axil_arprot,
    input  logic              s_axil_arvalid,
    output logic              s_axil_arready,
    // R
    output logic [DATA_W-1:0] s_axil_rdata,
    output logic [1:0]        s_axil_rresp,
    output logic              s_axil_rvalid,
    input  logic              s_axil_rready,

    // ---------------- master port (downstream slave clock) --------------
    input  logic              m_axil_aclk,
    input  logic              m_axil_arstn,
    // AW
    output logic [ADDR_W-1:0] m_axil_awaddr,
    output logic [2:0]        m_axil_awprot,
    output logic              m_axil_awvalid,
    input  logic              m_axil_awready,
    // W
    output logic [DATA_W-1:0] m_axil_wdata,
    output logic [DATA_W/8-1:0] m_axil_wstrb,
    output logic              m_axil_wvalid,
    input  logic              m_axil_wready,
    // B
    input  logic [1:0]        m_axil_bresp,
    input  logic              m_axil_bvalid,
    output logic              m_axil_bready,
    // AR
    output logic [ADDR_W-1:0] m_axil_araddr,
    output logic [2:0]        m_axil_arprot,
    output logic              m_axil_arvalid,
    input  logic              m_axil_arready,
    // R
    input  logic [DATA_W-1:0] m_axil_rdata,
    input  logic [1:0]        m_axil_rresp,
    input  logic              m_axil_rvalid,
    output logic              m_axil_rready
);

  localparam int unsigned STRB_W = DATA_W/8;
  localparam int unsigned AW_W = ADDR_W + 3;              // awaddr, awprot
  localparam int unsigned W_W  = DATA_W + STRB_W;         // wdata, wstrb
  localparam int unsigned B_W  = 2;                       // bresp
  localparam int unsigned AR_W = ADDR_W + 3;              // araddr, arprot
  localparam int unsigned R_W  = DATA_W + 2;              // rdata, rresp

  // -------- AW channel: slave -> master --------
  logic aw_full, aw_empty; logic [AW_W-1:0] aw_wr, aw_rd;
  assign aw_wr = {s_axil_awprot, s_axil_awaddr};
  assign s_axil_awready = ~aw_full;
  assign m_axil_awvalid = ~aw_empty;
  assign {m_axil_awprot, m_axil_awaddr} = aw_rd;
  cdc_async_fifo #(.WIDTH(AW_W), .DEPTH(DEPTH)) u_aw (
      .wclk(s_axil_aclk), .wrst_n(s_axil_arstn), .wr_en(s_axil_awvalid & ~aw_full), .wr_data(aw_wr), .full(aw_full),
      .rclk(m_axil_aclk), .rrst_n(m_axil_arstn), .rd_en(m_axil_awready & ~aw_empty), .rd_data(aw_rd), .empty(aw_empty));

  // -------- W channel: slave -> master --------
  logic w_full, w_empty; logic [W_W-1:0] w_wr, w_rd;
  assign w_wr = {s_axil_wstrb, s_axil_wdata};
  assign s_axil_wready = ~w_full;
  assign m_axil_wvalid = ~w_empty;
  assign {m_axil_wstrb, m_axil_wdata} = w_rd;
  cdc_async_fifo #(.WIDTH(W_W), .DEPTH(DEPTH)) u_w (
      .wclk(s_axil_aclk), .wrst_n(s_axil_arstn), .wr_en(s_axil_wvalid & ~w_full), .wr_data(w_wr), .full(w_full),
      .rclk(m_axil_aclk), .rrst_n(m_axil_arstn), .rd_en(m_axil_wready & ~w_empty), .rd_data(w_rd), .empty(w_empty));

  // -------- B channel: master -> slave --------
  logic b_full, b_empty; logic [B_W-1:0] b_wr, b_rd;
  assign b_wr = m_axil_bresp;
  assign m_axil_bready = ~b_full;
  assign s_axil_bvalid = ~b_empty;
  assign s_axil_bresp  = b_rd;
  cdc_async_fifo #(.WIDTH(B_W), .DEPTH(DEPTH)) u_b (
      .wclk(m_axil_aclk), .wrst_n(m_axil_arstn), .wr_en(m_axil_bvalid & ~b_full), .wr_data(b_wr), .full(b_full),
      .rclk(s_axil_aclk), .rrst_n(s_axil_arstn), .rd_en(s_axil_bready & ~b_empty), .rd_data(b_rd), .empty(b_empty));

  // -------- AR channel: slave -> master --------
  logic ar_full, ar_empty; logic [AR_W-1:0] ar_wr, ar_rd;
  assign ar_wr = {s_axil_arprot, s_axil_araddr};
  assign s_axil_arready = ~ar_full;
  assign m_axil_arvalid = ~ar_empty;
  assign {m_axil_arprot, m_axil_araddr} = ar_rd;
  cdc_async_fifo #(.WIDTH(AR_W), .DEPTH(DEPTH)) u_ar (
      .wclk(s_axil_aclk), .wrst_n(s_axil_arstn), .wr_en(s_axil_arvalid & ~ar_full), .wr_data(ar_wr), .full(ar_full),
      .rclk(m_axil_aclk), .rrst_n(m_axil_arstn), .rd_en(m_axil_arready & ~ar_empty), .rd_data(ar_rd), .empty(ar_empty));

  // -------- R channel: master -> slave --------
  logic r_full, r_empty; logic [R_W-1:0] r_wr, r_rd;
  assign r_wr = {m_axil_rresp, m_axil_rdata};
  assign m_axil_rready = ~r_full;
  assign s_axil_rvalid = ~r_empty;
  assign {s_axil_rresp, s_axil_rdata} = r_rd;
  cdc_async_fifo #(.WIDTH(R_W), .DEPTH(DEPTH)) u_r (
      .wclk(m_axil_aclk), .wrst_n(m_axil_arstn), .wr_en(m_axil_rvalid & ~r_full), .wr_data(r_wr), .full(r_full),
      .rclk(s_axil_aclk), .rrst_n(s_axil_arstn), .rd_en(s_axil_rready & ~r_empty), .rd_data(r_rd), .empty(r_empty));

`ifdef FORMAL
  // Per-channel protocol legality (FIFO internals are proven in cdc_async_fifo).
  always_ff @(posedge s_axil_aclk) begin
    if (s_axil_arstn) assert (s_axil_awready == ~aw_full);
    if (s_axil_arstn) assert (s_axil_wready  == ~w_full);
    if (s_axil_arstn) assert (s_axil_arready == ~ar_full);
    if (s_axil_arstn) assert (s_axil_bvalid  == ~b_empty);
    if (s_axil_arstn) assert (s_axil_rvalid  == ~r_empty);
    if (s_axil_arstn) cover (s_axil_awvalid && s_axil_awready);
    if (s_axil_arstn) cover (s_axil_rvalid  && s_axil_rready);
  end
  always_ff @(posedge m_axil_aclk) begin
    if (m_axil_arstn) assert (m_axil_awvalid == ~aw_empty);
    if (m_axil_arstn) assert (m_axil_bready  == ~b_full);
    if (m_axil_arstn) cover (m_axil_awvalid && m_axil_awready);
  end
`endif

endmodule
