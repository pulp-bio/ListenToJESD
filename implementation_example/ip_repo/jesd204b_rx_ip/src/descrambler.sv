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
//   JESD204B 32-bit Descrambler.
//   Implements a self-synchronizing descrambler using a x^15+x^14+1,
//   defined for a 32-bit parallel data interface. The LFSR operates in
//   little-endian order. This descrambler is useful for reversing the scrambling
//   applied by JESD204B transmitters.
//
// Parameters:
//   WIDTH         - Bit width of parallel input data (default: 32).
//   SEED          - Initial value of the LFSR (default: 15'h7f80).
//
// Ports:
//   clk_i              - Clock input.
//   rst_ni             - Active-low synchronous reset.
//   descramble_en_i    - Enable signal for descrambling.
//   data_i             - Scrambled input data.
//   data_o             - Descrambled output data.
//------------------------------------------------------------------------------

module descrambler #(
  parameter int DATA_WIDTH = 32,
  parameter logic [14:0] SEED = 15'h7fff
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              descramble_en_i,
  input  logic [DATA_WIDTH-1:0]  data_i,
  output logic [DATA_WIDTH-1:0]  data_o
);

  // LFSR seed register
  logic [14:0] seed_q;

  // LFSR state and tap output
  logic [DATA_WIDTH-1+15:0] lfsr_state;
  logic [DATA_WIDTH-1:0]    lfsr_tap_out;

  // Byte-reversed signals for little-endian operation
  logic [DATA_WIDTH-1:0] byte_reversed_in;
  logic [DATA_WIDTH-1:0] byte_reversed_out;

  // Byte-reversal (little-endian reordering)
  genvar i;
  generate
    for (i = 0; i < DATA_WIDTH / 8; i++) begin : gen_byte_reverse
      assign byte_reversed_in[DATA_WIDTH-1 - i*8 -: 8] = data_i[i*8 +: 8];
      assign data_o[DATA_WIDTH-1 - i*8 -: 8]           = byte_reversed_out[i*8 +: 8];
    end
  endgenerate

  assign lfsr_state   = {seed_q, byte_reversed_in};
  assign lfsr_tap_out = lfsr_state[DATA_WIDTH+14:15] ^ lfsr_state[DATA_WIDTH+13:14] ^ byte_reversed_in;

  // Descrambling logic
  always_comb begin
    if (!descramble_en_i) begin
      byte_reversed_out = byte_reversed_in;
    end else begin
      byte_reversed_out = lfsr_tap_out;
    end
  end

  // Seed register update
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      seed_q <= SEED;
    end else begin
      seed_q <= lfsr_state[14:0];
    end
  end

endmodule

