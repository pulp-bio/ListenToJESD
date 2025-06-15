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
// -----------------------------------------------------------------------------
// Module: jesd_stream_flattener
// Description: This module receives AXI-Stream data from jesd204c block, performs a byte swap on
//              each 16-bit segment, converts the data width, and performs a
//              clock domain conversion before outputting the modified stream.
// -----------------------------------------------------------------------------

module jesd_stream_flattener_32_128 (
  // AXI-Stream Input Interface
  input  wire              s_axis_aclk,
  input  wire              s_axis_aresetn,
  input  wire [32-1:0]     s_axis_tdata,
  input  wire              s_axis_tvalid,

  // AXI-Stream Output Interface
  input  wire              m_axis_aclk,
  input  wire              m_axis_aresetn,
  output wire [128-1:0]    m_axis_tdata,
  output wire              m_axis_tvalid
);

  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam NUM_WORDS = 32 / 16;  // Number of 16-bit words in the input data

  // ---------------------------------------------------------------------------
  // Internal Signals
  // ---------------------------------------------------------------------------
  wire [128-1:0] wide_tdata;      // Intermediate wide data after width conversion
  wire [32-1:0] swapped_tdata;      // Intermediate data after swap
  wire           wide_tvalid;     // Valid signal for intermediate wide data

  // ---------------------------------------------------------------------------
  // Byte-Swapping Logic
  // For each 16-bit chunk in the input data, swap the upper and lower bytes.
  // ---------------------------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < NUM_WORDS; i = i + 1) begin : byte_swap_loop
      wire [7:0] upper_byte = s_axis_tdata[(16*i)+15:(16*i)+8];
      wire [7:0] lower_byte = s_axis_tdata[(16*i)+7:(16*i)];
      
      assign swapped_tdata[(16*(i+1))-1 : (16*i)] = {lower_byte, upper_byte};
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // Data Width Conversion Module
  // Converts the input data width to a wider output data width.
  // ---------------------------------------------------------------------------
  axis_dwconv_32_128 data_width_converter (
    .aclk    (s_axis_aclk),
    .aresetn (s_axis_aresetn),
    .s_axis_tdata   (swapped_tdata),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (),                // Unused tready signal

    .m_axis_tdata   (wide_tdata),
    .m_axis_tvalid  (wide_tvalid),
    .m_axis_tready  (1'b1)             // Always ready to accept data (no support for backpressure)
  );

  // ---------------------------------------------------------------------------
  // Clock Domain Conversion Module
  // Transfers the data from the input clock domain to the output clock domain.
  // ---------------------------------------------------------------------------
  axis_clkconv_128 clock_converter (
    .s_axis_aclk    (s_axis_aclk),
    .s_axis_aresetn (s_axis_aresetn),
    .s_axis_tdata   (wide_tdata),
    .s_axis_tvalid  (wide_tvalid),
    .s_axis_tready  (),                // Unused tready signal

    .m_axis_aclk    (m_axis_aclk),
    .m_axis_aresetn (m_axis_aresetn),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (1'b1)            // Always ready to accept data (no support for backpressure)
  );

endmodule
