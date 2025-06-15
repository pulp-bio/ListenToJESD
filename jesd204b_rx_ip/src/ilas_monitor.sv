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
//   ILAS (Initial Lane Alignment Sequence) Monitor for JESD204B.
//   Detects the end of the ILAS sequence and signals when user data is ready.
//   Extracts and Buffers ILAS configuration data, can be used for further processing.
//
// Parameters:
//   PARALLEL_OCTETS           - Number of octets processed in parallel.
//   DATA_WIDTH                - Bit width of each data word (PATH_WIDTH * 8).
//   F (OCTETS_PER_MULTIFRAME) - Length of ILAS configuration sequence in octets.
//
// Ports:
//   clk_i           - Clock input.
//   rst_ni          - Active-low synchronous reset.
//   data_i          - Input data word.
//   char_is_k28_i   - Indicator bits showing which characters are K28 symbols.
//   data_ready_o    - Indicates user data can be consumed.
//------------------------------------------------------------------------------
module ilas_monitor #(
  parameter int PARALLEL_OCTETS        = 4,
  parameter int DATA_WIDTH             = 32,
  parameter int F                      = 32
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,
  input  logic [DATA_WIDTH-1:0]        data_i,
  input  logic [PARALLEL_OCTETS-1:0]   char_is_k28_i,
  output logic                         data_ready_o
);

  localparam int ILAS_CONFIG_WORDS = 4;

  // FSM States
  typedef enum logic {
    ST_DATA,
    ST_ILAS
  } state_e;

  state_e state_q, state_d;

  // Signals
  logic last_octet_seen_d;
  logic ilas_start_d;

  logic ilas_config_valid_q;
  logic [1:0] ilas_config_addr_q;
  logic [DATA_WIDTH-1:0] ilas_config_data_q;

  // Output logic
  assign data_ready_o = (state_d == ST_DATA);

  // Detect end of ILAS : Check for K28.3 in the last octet
  always_ff @(posedge clk_i) begin
    if (!rst_ni || (char_is_k28_i[PARALLEL_OCTETS-1] && data_i[31:29] == 3'h3)) begin
      last_octet_seen_d <= 1'b1;
    end else begin
      last_octet_seen_d <= 1'b0;
    end
  end

  // Next State Logic
  always_comb begin
    state_d = state_q;
    if (rst_ni && last_octet_seen_d) begin
      if (char_is_k28_i[0] != 1'b1) begin
        state_d = ST_DATA;
      end
    end
  end

  // FSM State Register
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= ST_ILAS;
    end else begin
      state_q <= state_d;
    end
  end

  // ILAS Start Detection : Detecting K28.4 
  assign ilas_start_d = char_is_k28_i[1] && (data_i[15:13] == 3'h4);

  // ILAS Config Valid Detection
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      ilas_config_valid_q <= 1'b0;
    end else if (state_q == ST_ILAS) begin
      if (ilas_start_d) begin
        ilas_config_valid_q <= 1'b1;
      end else if (ilas_config_addr_q == ILAS_CONFIG_WORDS-1) begin
        ilas_config_valid_q <= 1'b0;
      end
    end
  end

  // ILAS Config Address Increment
  always_ff @(posedge clk_i) begin
    if (ilas_config_valid_q) begin
        ilas_config_addr_q <= ilas_config_addr_q + 1;
    end else begin
        ilas_config_addr_q <= '0;
    end
  end

  // ILAS Config Data Capture
  always_ff @(posedge clk_i) begin
    if (ilas_config_valid_q) begin
        ilas_config_data_q <= data_i;
    end
  end

endmodule