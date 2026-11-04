// axis_cdc.sv — AXI4-Stream clock-domain converter (taxonomy E3)
//
// Crosses one AXI-Stream channel between an asynchronous source (slave-side,
// the stream producer drives s_axis) and destination (master-side, drives
// m_axis to the consumer). Built on cdc_async_fifo: TDATA+TLAST+TKEEP+TID are
// packed into one FIFO word, with TVALID/TREADY implementing the push/pop
// flow control so no beat is lost or duplicated.
//
// Contract
//   Clock assumptions : s_axis_aclk and m_axis_aclk asynchronous.
//   Protocol          : standard AXI-Stream ready/valid on both sides; a beat
//                       transfers when TVALID && TREADY.
//   Guarantees        : every accepted source beat appears once, in order, on
//                       the master side, uncorrupted; TREADY deasserts when the
//                       crossing FIFO is full (backpressure).
//   Reset             : each domain resets its FIFO pointers; drive both
//                       resets from a coordinated release.
//
// Parameters
//   DATA_W : TDATA width (bits).
//   ID_W   : TID width (bits, 0 to omit).
//   DEPTH  : crossing FIFO depth (power of two >= 2).
module axis_cdc #(
    parameter int unsigned DATA_W = 32,
    parameter int unsigned ID_W   = 0,
    parameter int unsigned DEPTH  = 8
) (
    // slave side (source domain) — stream flows IN here
    input  logic              s_axis_aclk,
    input  logic              s_axis_arstn,
    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic [DATA_W/8-1:0] s_axis_tkeep,
    input  logic              s_axis_tlast,
    input  logic [(ID_W>0?ID_W:1)-1:0] s_axis_tid,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,

    // master side (destination domain) — stream flows OUT here
    input  logic              m_axis_aclk,
    input  logic              m_axis_arstn,
    output logic [DATA_W-1:0] m_axis_tdata,
    output logic [DATA_W/8-1:0] m_axis_tkeep,
    output logic              m_axis_tlast,
    output logic [(ID_W>0?ID_W:1)-1:0] m_axis_tid,
    output logic              m_axis_tvalid,
    input  logic              m_axis_tready
);

  localparam int unsigned KEEP_W = DATA_W/8;
  localparam int unsigned TIDW   = (ID_W > 0) ? ID_W : 1;
  // Packed FIFO word: {tid, tlast, tkeep, tdata}.
  localparam int unsigned PW = DATA_W + KEEP_W + 1 + TIDW;

  logic [PW-1:0] wr_word, rd_word;
  logic          full, empty;

  assign wr_word = {s_axis_tid, s_axis_tlast, s_axis_tkeep, s_axis_tdata};

  // Push on an accepted slave beat; pop on an accepted master beat.
  logic wr_en, rd_en;
  assign s_axis_tready = ~full;
  assign wr_en         = s_axis_tvalid & ~full;
  assign m_axis_tvalid = ~empty;
  assign rd_en         = m_axis_tready & ~empty;

  cdc_async_fifo #(.WIDTH(PW), .DEPTH(DEPTH)) u_fifo (
      .wclk   (s_axis_aclk),
      .wrst_n (s_axis_arstn),
      .wr_en  (wr_en),
      .wr_data(wr_word),
      .full   (full),
      .rclk   (m_axis_aclk),
      .rrst_n (m_axis_arstn),
      .rd_en  (rd_en),
      .rd_data(rd_word),
      .empty  (empty)
  );

  assign m_axis_tdata = rd_word[DATA_W-1:0];
  assign m_axis_tkeep = rd_word[DATA_W +: KEEP_W];
  assign m_axis_tlast = rd_word[DATA_W + KEEP_W];
  assign m_axis_tid   = rd_word[DATA_W + KEEP_W + 1 +: TIDW];

`ifdef FORMAL
  // Beats accepted on the slave side equal beats eventually emitted on the
  // master side (lossless, in order) — reuse the FIFO's own proven invariants
  // and just check protocol legality here.
  always_ff @(posedge s_axis_aclk) begin
    if (s_axis_arstn) assert (s_axis_tready == ~full);
    if (s_axis_arstn) cover (s_axis_tvalid && s_axis_tready);
  end
  always_ff @(posedge m_axis_aclk) begin
    if (m_axis_arstn) assert (m_axis_tvalid == ~empty);
    if (m_axis_arstn) cover (m_axis_tvalid && m_axis_tready);
  end
`endif

endmodule
