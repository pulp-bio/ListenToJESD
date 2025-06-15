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
// Module: axi_stream_flattener_parallel
// Description: This module instantiates multiple axi_stream_flattener modules
//              working in parallel. Each flattener processes its own AXI-Stream
//              input and outputs the flattened data.
// -----------------------------------------------------------------------------


module jesd_stream_flattener_wrapper #(
  parameter JESD_LANE_NUMBER = 2, // Number of JESD Lanes per JESD204C IP
  parameter JESD_CONVERTERS_PER_LANE = 8, // Number of converters per JESD Lane
  parameter JESD_CORE_CLK_SAMPLE_CLK_RATIO = 4, // Core clock to sample clock ratio
  
  parameter AXI_STREAM_IN_WIDTH = JESD_LANE_NUMBER * JESD_CONVERTERS_PER_LANE * 16 / JESD_CORE_CLK_SAMPLE_CLK_RATIO,  // Input data width (64 by default for 2 lanes)      
  parameter AXI_STREAM_OUT_WIDTH = AXI_STREAM_IN_WIDTH * JESD_CORE_CLK_SAMPLE_CLK_RATIO // Output data width (4x line rate in 160x pll mode)
)(
  // Clock and reset signals for input AXI-Stream
  input  wire                               s_axis_aclk,
  input  wire                               s_axis_aresetn,

  // Clock and reset signals for output AXI-Stream
  input  wire                               m_axis_aclk,
  input  wire                               m_axis_aresetn,

  //  AXI-Stream Input Interface
  input  wire [AXI_STREAM_IN_WIDTH-1:0]  s_axis_tdata,
  input  wire                            s_axis_tvalid,

  // AXI-Stream Output Interface
  output wire [AXI_STREAM_OUT_WIDTH-1:0] m_axis_tdata,
  output wire                            m_axis_tvalid
);




  localparam JESD204C_LANE_WIDTH = 32; // width of decoded data lane, must be 32 for JESD204C IP, change widths depending on IP 
  localparam JESD204C_FLATTENED_LANE_WIDTH = JESD204C_LANE_WIDTH*JESD_CORE_CLK_SAMPLE_CLK_RATIO; // width of flattened data lane. it is 4x the input for the 8chan/lane mode


  localparam NUM_FLATTENERS = 2;//AXI_STREAM_IN_WIDTH / JESD204C_LANE_WIDTH;

  // ---------------------------------------------------------------------------
  // Generate Multiple axi_stream_flattener Instances
  // ---------------------------------------------------------------------------

  wire  [NUM_FLATTENERS-1:0] i_tvalid;
  // only output 1 if all lanes are valid
  assign m_axis_tvalid = &i_tvalid;
  
  genvar i;
  generate
    for (i = 0; i < NUM_FLATTENERS; i = i + 1) begin : flatteners_gen
    
      jesd_stream_flattener_32_128 flattener_inst (
        .s_axis_aclk    (s_axis_aclk),
        .s_axis_aresetn (s_axis_aresetn),
        .s_axis_tdata   (s_axis_tdata[(i+1)*JESD204C_LANE_WIDTH-1 : i*JESD204C_LANE_WIDTH]),
        .s_axis_tvalid  (s_axis_tvalid),

        .m_axis_aclk    (m_axis_aclk),
        .m_axis_aresetn (m_axis_aresetn),
        .m_axis_tdata   (m_axis_tdata[(i+1)*JESD204C_FLATTENED_LANE_WIDTH-1 : i*JESD204C_FLATTENED_LANE_WIDTH]),
        .m_axis_tvalid  (i_tvalid[i])
      );

    end
  endgenerate

endmodule