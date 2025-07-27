// Copyright 2025 ETH Zurich
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// Soumyo Bhattacharjee  <sbhattacharj@student.ethz.ch>
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
  logic [$clog2(BEATS_PER_FRAME)-1:0] frame_ctr_d;

  always_comb begin
    if (frame_ctr_q == BEATS_PER_FRAME - 1)
      frame_ctr_d = '0;
    else
      frame_ctr_d = frame_ctr_q + 1;
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      frame_ctr_q <= '0;
    end else begin
      frame_ctr_q <= frame_ctr_d;
    end
  end

  assign sof_o = {{PARALLEL_OCTETS-1{1'b0}}, (frame_ctr_q == 0)};
  assign eof_o = {(frame_ctr_q == BEATS_PER_FRAME - 1), {PARALLEL_OCTETS-1{1'b0}}};

  // Multiframe Counter
  logic [$clog2(BEATS_PER_MULTIFRAME)-1:0] multiframe_ctr_q;
  logic [$clog2(BEATS_PER_MULTIFRAME)-1:0] multiframe_ctr_d;

  always_comb begin
    if (multiframe_ctr_q == BEATS_PER_MULTIFRAME - 1) begin
      multiframe_ctr_d = '0;
    end else begin
      multiframe_ctr_d = multiframe_ctr_q + 1;
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      multiframe_ctr_q <= '0;
    end else begin
      multiframe_ctr_q <= multiframe_ctr_d;
    end
  end

  assign somf_o = {{PARALLEL_OCTETS-1{1'b0}}, (multiframe_ctr_q == 0)};
  assign eomf_o = {(multiframe_ctr_q == BEATS_PER_MULTIFRAME - 1), {PARALLEL_OCTETS-1{1'b0}}};

endmodule
