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
//
//------------------------------------------------------------------------------
// Description:
//   Octet alignment module for JESD204B datapath. Aligns incoming data based on
//   an alignment offset index. Stitches two data cycles together to shift and
//   extract a correctly aligned data window.
//
// Parameters:
//   PARALLEL_OCTETS  - Number of parallel octets.
//   DATA_WIDTH       - Width of the data frame (typically PARALLEL_OCTETS * 8).
//
// Ports:
//   clk_i             - Input clock.
//   rst_ni            - Active-low synchronous reset.
//   in_data_i         - Input data word.
//   in_char_is_k28_i  - K28 indicator for each character lane.
//   octet_align_idx_i - Octet offset index for alignment.
//   out_data_o        - Aligned output data.
//   out_char_is_k28_o - Aligned output K28 indicators.
//------------------------------------------------------------------------------

module octet_align #(
  parameter int PARALLEL_OCTETS = 4,
  parameter int DATA_WIDTH      = 32
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic [DATA_WIDTH-1:0]      in_data_i,
  input  logic [PARALLEL_OCTETS-1:0] in_char_is_k28_i,
  input  logic [2:0]                 octet_align_idx_i,
  output logic [DATA_WIDTH-1:0]      out_data_o,
  output logic [PARALLEL_OCTETS-1:0] out_char_is_k28_o
);

  // Local parameter for offset extraction
  localparam int LOG2_PARALLEL_OCTETS = $clog2(PARALLEL_OCTETS);

  // Register previous cycle data
  logic [DATA_WIDTH-1:0]     prev_data_q;
  logic [PARALLEL_OCTETS-1:0]   prev_char_is_k28_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      prev_data_q         <= '0;
      prev_char_is_k28_q  <= '0;
    end else begin
      prev_data_q         <= in_data_i;
      prev_char_is_k28_q  <= in_char_is_k28_i;
    end
  end

  // Concatenated window of two cycles
  logic [2*DATA_WIDTH-1:0]     data_comb;
  logic [2*PARALLEL_OCTETS-1:0]   char_is_k28_comb;

  assign data_comb         = {in_data_i, prev_data_q};
  assign char_is_k28_comb  = {in_char_is_k28_i, prev_char_is_k28_q};

  // Use alignment index to select output slice
  logic [LOG2_PARALLEL_OCTETS-1:0] offset;
  assign offset = octet_align_idx_i[LOG2_PARALLEL_OCTETS-1:0];

  assign out_data_o        = data_comb[offset * 8 +: DATA_WIDTH];
  assign out_char_is_k28_o = char_is_k28_comb[offset +: PARALLEL_OCTETS];

endmodule
