// apb_cdc.sv — APB clock-domain bridge (taxonomy E4)
//
// Bridges an APB3 transaction from the requester clock domain to a completer
// in another clock domain. APB is non-pipelined (one outstanding transfer),
// which maps directly onto a request/response handshake pair: the request
// (PADDR/PWRITE/PWDATA/PSTRB) crosses on cdc_bus_handshake, the completer runs
// its own APB access, and the response (PRDATA/PSLVERR) crosses back on a
// second handshake. PREADY on the requester side is held low until the
// response returns.
//
// Contract
//   Clock assumptions : req_pclk and cmp_pclk asynchronous.
//   Protocol          : APB3 on both sides (one transfer at a time).
//   Guarantees        : exactly one completer access per requester transfer,
//                       with PRDATA/PSLVERR returned uncorrupted; no transfer
//                       lost, none duplicated.
//   Reset             : coordinated reset release across both domains.
//
// Parameters
//   ADDR_W : PADDR width.
//   DATA_W : PWDATA/PRDATA width.
module apb_cdc #(
    parameter int unsigned ADDR_W = 16,
    parameter int unsigned DATA_W = 32
) (
    // Requester-side APB (slave to the upstream master)
    input  logic              req_pclk,
    input  logic              req_presetn,
    input  logic              req_psel,
    input  logic              req_penable,
    input  logic              req_pwrite,
    input  logic [ADDR_W-1:0] req_paddr,
    input  logic [DATA_W-1:0] req_pwdata,
    input  logic [DATA_W/8-1:0] req_pstrb,
    output logic [DATA_W-1:0] req_prdata,
    output logic              req_pready,
    output logic              req_pslverr,

    // Completer-side APB (master to the downstream slave)
    input  logic              cmp_pclk,
    input  logic              cmp_presetn,
    output logic              cmp_psel,
    output logic              cmp_penable,
    output logic              cmp_pwrite,
    output logic [ADDR_W-1:0] cmp_paddr,
    output logic [DATA_W-1:0] cmp_pwdata,
    output logic [DATA_W/8-1:0] cmp_pstrb,
    input  logic [DATA_W-1:0] cmp_prdata,
    input  logic              cmp_pready,
    input  logic              cmp_pslverr
);

  localparam int unsigned STRB_W = DATA_W/8;
  localparam int unsigned REQ_W  = 1 + ADDR_W + DATA_W + STRB_W;  // pwrite,addr,wdata,strb
  localparam int unsigned RSP_W  = DATA_W + 1;                    // prdata,pslverr

  // ---- Requester side: launch one transfer on the APB ACCESS phase ----
  // APB signals a transfer in the ENABLE (access) phase: psel && penable.
  // Hold it until the response returns (req_pready).
  logic         req_busy;        // a transfer is in flight
  logic         rsp_valid_q;     // rsp_d_valid delayed one cycle (see below)
  logic         req_s_valid, req_s_ready;
  logic [REQ_W-1:0] req_word;

  assign req_word    = {req_pwrite, req_paddr, req_pwdata, req_pstrb};
  // Launch when the master asserts the access phase and we are idle.
  assign req_s_valid = req_psel & req_penable & ~req_busy;

  logic             rsp_d_valid;
  logic [RSP_W-1:0] rsp_word_r;

  always_ff @(posedge req_pclk or negedge req_presetn) begin
    if (!req_presetn) begin
      req_busy    <= 1'b0;
      rsp_valid_q <= 1'b0;
    end else begin
      // rsp_word_r (u_rsp's d_data) is valid the cycle AFTER rsp_d_valid, so
      // delay the strobe one cycle; PREADY and PRDATA are then presented
      // together on the rsp_valid_q cycle, when rsp_word_r is stable.
      rsp_valid_q <= rsp_d_valid;
      if (req_s_valid && req_s_ready)
        req_busy <= 1'b1;                 // transfer accepted into the bridge
      else if (rsp_valid_q)
        req_busy <= 1'b0;                 // response delivered to the master
    end
  end

  // PREADY completes the APB access the cycle the response word is valid, and
  // PRDATA/PSLVERR are driven combinationally from the (now stable) crossed
  // response word on that same cycle.
  assign req_pready  = rsp_valid_q;
  assign req_prdata  = rsp_word_r[DATA_W-1:0];
  assign req_pslverr = rsp_word_r[DATA_W];

  // Request crossing: requester -> completer.
  logic [REQ_W-1:0] cmp_req_word;
  logic             cmp_req_valid, cmp_req_ready;
  cdc_bus_handshake #(.WIDTH(REQ_W)) u_req (
      .sclk   (req_pclk),
      .srst_n (req_presetn),
      .s_data (req_word),
      .s_valid(req_s_valid),
      .s_ready(req_s_ready),
      .dclk   (cmp_pclk),
      .drst_n (cmp_presetn),
      .d_data (cmp_req_word),
      .d_valid(cmp_req_valid),
      .d_ready(cmp_req_ready)
  );

  // ---- Completer side: run one APB access per crossed request ----
  // States: IDLE -> LATCH (capture the crossed request, which cdc_bus_handshake
  // presents on d_data the cycle AFTER its d_valid strobe) -> SETUP (psel) ->
  // ACCESS (psel&penable, wait pready) -> done.
  typedef enum logic [1:0] {C_IDLE, C_LATCH, C_SETUP, C_ACCESS} cstate_e;
  cstate_e cstate;
  logic [REQ_W-1:0] cmp_req_hold;
  logic             rsp_s_valid;
  logic             rsp_s_ready;    // response-crossing ready (completer side)
  logic [RSP_W-1:0] rsp_word;

  assign cmp_req_ready = (cstate == C_IDLE);

  always_ff @(posedge cmp_pclk or negedge cmp_presetn) begin
    if (!cmp_presetn) begin
      cstate       <= C_IDLE;
      cmp_req_hold <= '0;
      rsp_s_valid  <= 1'b0;
      rsp_word     <= '0;
    end else begin
      rsp_s_valid <= 1'b0;
      case (cstate)
        C_IDLE:
          if (cmp_req_valid)
            cstate <= C_LATCH;        // d_data not yet valid this cycle
        C_LATCH: begin
          cmp_req_hold <= cmp_req_word; // d_data now stable
          cstate       <= C_SETUP;
        end
        C_SETUP:
          cstate <= C_ACCESS;
        C_ACCESS:
          if (cmp_pready && rsp_s_ready) begin
            rsp_word    <= {cmp_pslverr, cmp_prdata};
            rsp_s_valid <= 1'b1;         // launch the response crossing
            cstate      <= C_IDLE;
          end
        default: cstate <= C_IDLE;
      endcase
    end
  end

  // Drive the completer APB.
  assign cmp_psel    = (cstate == C_SETUP) || (cstate == C_ACCESS);
  assign cmp_penable = (cstate == C_ACCESS);
  assign cmp_pwrite  = cmp_req_hold[REQ_W-1];
  assign cmp_paddr   = cmp_req_hold[STRB_W + DATA_W +: ADDR_W];
  assign cmp_pwdata  = cmp_req_hold[STRB_W +: DATA_W];
  assign cmp_pstrb   = cmp_req_hold[0 +: STRB_W];

  // Response crossing: completer -> requester.
  cdc_bus_handshake #(.WIDTH(RSP_W)) u_rsp (
      .sclk   (cmp_pclk),
      .srst_n (cmp_presetn),
      .s_data (rsp_word),
      .s_valid(rsp_s_valid),
      .s_ready(rsp_s_ready),
      .dclk   (req_pclk),
      .drst_n (req_presetn),
      .d_data (rsp_word_r),
      .d_valid(rsp_d_valid),
      .d_ready(1'b1)
  );

`ifdef FORMAL
  // APB protocol legality (plain boolean implications — Yosys read_verilog
  // immediate asserts do not accept the |-> SVA operator).
  always_ff @(posedge cmp_pclk) begin
    // APB: an access phase (penable) only occurs while selected.
    if (cmp_presetn) assert (!cmp_penable || cmp_psel);
    // penable is never asserted outside the ACCESS state.
    if (cmp_presetn) assert (cmp_penable == (cstate == C_ACCESS));
    if (cmp_presetn) cover (cstate == C_ACCESS && cmp_pready);
  end
  always_ff @(posedge req_pclk) begin
    // PREADY only rises after a response has crossed back (the delayed strobe).
    if (req_presetn) assert (req_pready == rsp_valid_q);
    if (req_presetn) cover (req_pready);
  end
`endif

endmodule
