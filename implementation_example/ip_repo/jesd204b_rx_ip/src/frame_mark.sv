//------------------------------------------------------------------------------
// Description:
//   Frame and Multiframe Marker Generator for JESD204B.
//   Generates Start-of-Frame (SOF), End-of-Frame (EOF),
//   Start-of-Multiframe (SOMF), and End-of-Multiframe (EOMF) flags
//   based on datapath width.
//   Here, the sof and eof is always the same value since we produce 1 frame every clock cycle.
//
// Parameters:
//   PATH_WIDTH                - Number of octets processed per beat.
//   OCTETS_PER_FRAME (F)      - Number of octets in one JESD frame.
//   FRAMES_PER_MULTIFRAME (K) - Number of frames in one JESD multiframe.
//
// Ports:
//   clk_i   - Clock input.
//   rst_ni  - Active-low synchronous reset.
//   sof_o   - Indicates first beat of a frame.
//   eof_o   - Indicates last beat of a frame.
//   somf_o  - Indicates first beat of a multiframe.
//   eomf_o  - Indicates last beat of a multiframe.
//------------------------------------------------------------------------------

module frame_mark #(
  parameter int PARALLEL_OCTETS  = 4,
  parameter int F                = 4,
  parameter int K                = 8
) (
  input  logic                           clk_i,
  input  logic                           rst_ni,
  output logic [PARALLEL_OCTETS-1:0]     sof_o,
  output logic [PARALLEL_OCTETS-1:0]     eof_o,
  output logic [PARALLEL_OCTETS-1:0]     somf_o,
  output logic [PARALLEL_OCTETS-1:0]     eomf_o
);

  // Derived Parameters
  localparam int BEATS_PER_FRAME      = F / PARALLEL_OCTETS;
  localparam int BEATS_PER_MULTIFRAME = (F*K) / PARALLEL_OCTETS;

  // Frame Counter
  logic [$clog2(BEATS_PER_FRAME)-1:0] frame_ctr_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      frame_ctr_q <= '0;
    end else if (frame_ctr_q == BEATS_PER_FRAME - 1) begin
      frame_ctr_q <= '0;
    end else begin
      frame_ctr_q <= frame_ctr_q + 1;
    end
  end

  assign sof_o = {{PARALLEL_OCTETS-1{1'b0}}, (frame_ctr_q == 0)};
  assign eof_o = {(frame_ctr_q == BEATS_PER_FRAME - 1), {PARALLEL_OCTETS-1{1'b0}}};

  // Multiframe Counter
  logic [$clog2(BEATS_PER_MULTIFRAME)-1:0] multiframe_ctr_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      multiframe_ctr_q <= '0;
    end else if (multiframe_ctr_q == BEATS_PER_MULTIFRAME - 1) begin
      multiframe_ctr_q <= '0;
    end else begin
      multiframe_ctr_q <= multiframe_ctr_q + 1;
    end
  end

  assign somf_o = {{PARALLEL_OCTETS-1{1'b0}}, (multiframe_ctr_q == 0)};
  assign eomf_o = {(multiframe_ctr_q == BEATS_PER_MULTIFRAME - 1), {PARALLEL_OCTETS-1{1'b0}}};

endmodule
