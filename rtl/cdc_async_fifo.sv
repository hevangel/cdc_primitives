// cdc_async_fifo.sv — dual-clock asynchronous FIFO (covers C1, C2, C3)
//
// Classic Gray-pointer asynchronous FIFO: independent write and read clocks,
// a dual-port memory, and Gray-coded read/write pointers synchronised across
// the boundary to derive full and empty. This is the standard safe structure
// for streaming data between clock domains.
//
// Contract
//   Clock assumptions : wclk and rclk asynchronous.
//   Data assumptions  : write only when !full; read only when !empty
//                       (ready/valid style).
//   Guarantees        : FIFO ordering (first in, first out); no overflow
//                       (a write when full is ignored) and no underflow (a
//                       read when empty is ignored); every written word is
//                       read exactly once; full/empty are conservative (may
//                       lag reality by the pointer-sync latency but never
//                       assert unsafely).
//   Reset             : each domain resets its own pointers; use a common
//                       reset or per-domain rst_sync.
//   Physical          : Gray pointers must be bussed with matched skew; the
//                       memory is a true dual-port RAM.
//
// Parameters
//   WIDTH : data width.
//   DEPTH : number of entries, must be a power of two (>= 2).
module cdc_async_fifo #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned DEPTH = 8
) (
    // write domain
    input  logic             wclk,
    input  logic             wrst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    // read domain
    input  logic             rclk,
    input  logic             rrst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty
);

  localparam int unsigned AW = $clog2(DEPTH);

  // synthesis translate_off
  initial begin
    if (DEPTH < 2 || (DEPTH & (DEPTH - 1)) != 0)
      $fatal(1, "cdc_async_fifo: DEPTH must be a power of two >= 2 (got %0d)", DEPTH);
  end
  // synthesis translate_on

  function automatic logic [AW:0] bin2gray(input logic [AW:0] b);
    bin2gray = b ^ (b >> 1);
  endfunction

  // Dual-port memory.
  logic [WIDTH-1:0] mem [DEPTH];

  // Pointers are AW+1 bits: the extra MSB distinguishes full from empty.
  logic [AW:0] wbin, wbin_next, wgray, wgray_next;
  logic [AW:0] rbin, rbin_next, rgray, rgray_next;
  logic        do_write, do_read;

  // -------- write domain --------
  logic [AW:0] rgray_wsync1, rgray_wsync2;  // read pointer in write domain
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      rgray_wsync1 <= '0;
      rgray_wsync2 <= '0;
    end else begin
      rgray_wsync1 <= rgray;
      rgray_wsync2 <= rgray_wsync1;
    end
  end

  assign do_write   = wr_en & ~full;
  assign wbin_next  = wbin + {{AW{1'b0}}, do_write};
  assign wgray_next = bin2gray(wbin_next);

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin  <= '0;
      wgray <= '0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
    end
  end

  always_ff @(posedge wclk) begin
    if (do_write)
      mem[wbin[AW-1:0]] <= wr_data;
  end

  // Full when the next write pointer would equal the read pointer with the
  // top two Gray bits inverted (classic Gray-FIFO full test). The full test
  // uses wgray_next, which depends only on wbin (registered) and the current
  // full value through do_write — break that loop by comparing against the
  // CURRENT wgray incremented locally rather than the ternary on full.
  logic [AW:0] wgray_incr;  // gray of (wbin + 1), independent of `full`
  assign wgray_incr = bin2gray(wbin + {{AW{1'b0}}, 1'b1});
  assign full = (wgray_incr == {~rgray_wsync2[AW:AW-1], rgray_wsync2[AW-2:0]});

  // -------- read domain --------
  logic [AW:0] wgray_rsync1, wgray_rsync2;  // write pointer in read domain
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      wgray_rsync1 <= '0;
      wgray_rsync2 <= '0;
    end else begin
      wgray_rsync1 <= wgray;
      wgray_rsync2 <= wgray_rsync1;
    end
  end

  assign do_read    = rd_en & ~empty;
  assign rbin_next  = rbin + {{AW{1'b0}}, do_read};
  assign rgray_next = bin2gray(rbin_next);

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin  <= '0;
      rgray <= '0;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
    end
  end

  assign rd_data = mem[rbin[AW-1:0]];

  // Empty when read Gray pointer catches the synchronised write pointer.
  assign empty = (rgray == wgray_rsync2);

`ifdef FORMAL
  // Occupancy from the true binary pointers (for proof only — both are in the
  // design, this is a model-side observation using the gray-synced copies is
  // not needed because we reason on wbin/rbin directly).
  logic [AW:0] f_count;
  assign f_count = wbin - rbin;

  // The FIFO's cross-domain invariants hold under its documented reset
  // contract: a common reset (or coordinated per-domain release). Model that
  // by tying the two resets and starting from the reset state.
  logic f_pv = 1'b0;
  always_ff @(posedge wclk) begin
    if (!f_pv) assume (!wrst_n && !rrst_n);
    f_pv <= 1'b1;
    assume (wrst_n == rrst_n);

    // Gray pointer is always the Gray encoding of its binary pointer.
    if (wrst_n) assert (wgray == bin2gray(wbin));
    if (rrst_n) assert (rgray == bin2gray(rbin));
    // No overflow: occupancy never exceeds DEPTH.
    if (wrst_n) assert (f_count <= (AW+1)'(DEPTH));
    // When full, the write pointer is held (write suppressed): no overflow.
    if (wrst_n && full) assert (wbin_next == wbin);
    // When empty, the read pointer is held (read suppressed): no underflow.
    if (rrst_n && empty) assert (rbin_next == rbin);

    if (wrst_n) cover (full);
    if (rrst_n) cover (empty);
    if (wrst_n) cover (do_write);
    if (rrst_n) cover (do_read);
  end
`endif

endmodule
