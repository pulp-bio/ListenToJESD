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
//   JESD204B Receiver Top-Level Module.
//   Handles physical-layer deserialization, CGS/ILAS state tracking,
//   LMFC generation, frame alignment, optional descrambling,
//   elastic buffering, and per-link synchronization.
//
// Parameters:
//   LANES (L)                 - Number of physical JESD204B lanes.
//   LINKS                     - Number of logical links.
//   PARALLEL_OCTETS           - Number of octets processed per beat.
//   DATA_WIDTH                - Bit width of data per lane (PATH_WIDTH * 8).
//   OCTETS_PER_FRAME (F)      - Number of octets per frame.
//   FRAMES_PER_MULTIFRAME (K) - Number of frames per multiframe.
//   BUFFER_DELAY              - Delay in beats before releasing elastic buffer.
//   DESCRAMBLING              - Enable/disable descrambling (0: off, 1: on).
//
// Ports:
//   clk_i                 - Clock input.
//   rst_ni                - Active-low synchronous reset.
//   gtx_data_i            - GTX input data bus.
//   gtx_charisk_i         - GTX K-character indicators.
//   gtx_notintable_i      - GTX invalid-character flags.
//   gtx_disperr_i         - GTX disparity-error flags.
//   sysref_i              - SYSREF synchronization pulse.
//   gtx_ready_i           - GTX link ready input.
//   lmfc_clk_o            - Local multi-frame clock output.
//   sync_o                - Link synchronization outputs.
//   gtx_en_char_align_o   - GTX character-alignment enable.
//   rx_reset_gt_o         - Reset control for GTX receiver.
//   rx_data_o             - Aligned output data bus.
//   rx_valid_o            - Output data valid flag.
//   rx_sof_o              - Start-of-frame indicators.
//   rx_eof_o              - End-of-frame indicators.
//   rx_somf_o             - Start-of-multiframe indicators.
//   rx_eomf_o             - End-of-multiframe indicators.
//------------------------------------------------------------------------------

module rx #(
  parameter int L                 = 2,
  parameter int LINKS             = 1,
  parameter int PARALLEL_OCTETS   = 4,
  parameter int DATA_WIDTH        = 32,
  parameter int F                 = 4,
  parameter int K                 = 8,
  parameter int BUFFER_DELAY      = 0,
  parameter int DESCRAMBLING      = 0
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic [L*DATA_WIDTH-1:0]      gtx_data_i,
  input  logic [L*PARALLEL_OCTETS-1:0] gtx_charisk_i,
  input  logic [L*PARALLEL_OCTETS-1:0] gtx_notintable_i,
  input  logic [L*PARALLEL_OCTETS-1:0] gtx_disperr_i,

  input  logic                         sysref_i,
  input  logic                         gtx_ready_i,

  output logic                         lmfc_clk_o,
  output logic [LINKS-1:0]             sync_o,

  output logic                         gtx_en_char_align_o,
  output logic                         rx_reset_gt_o,

  output logic [L*DATA_WIDTH-1:0]      rx_data_o,
  output logic                         rx_valid_o,
  output logic [PARALLEL_OCTETS-1:0]   rx_sof_o,
  output logic [PARALLEL_OCTETS-1:0]   rx_eof_o,
  output logic [PARALLEL_OCTETS-1:0]   rx_somf_o,
  output logic [PARALLEL_OCTETS-1:0]   rx_eomf_o
);

  // Derived parameters
  localparam int DW = L * DATA_WIDTH;  // Total data width
  localparam int CW = L * PARALLEL_OCTETS; // Total control width for each control signal

  localparam int LOG2_PARALLEL_OCTETS = $clog2(PARALLEL_OCTETS);
  localparam int BEATS_PER_MULTIFRAME = (F * K) >> LOG2_PARALLEL_OCTETS;

  // Internal control signals
  logic [L-1:0] cgs_rst;
  logic [L-1:0] cgs_detected;
  logic [L-1:0] ifs_rst;
  logic [L-1:0] ifs_start;

  // Elastic buffer control
  logic          buffer_release_n;
  logic [L-1:0]  buffer_ready_n;
  logic          buffer_release_opp;
  logic          all_buffers_ready;

  // Pipelined GTX inputs
  logic [DW-1:0]  r_gtx_data;
  logic [CW-1:0]  r_gtx_charisk;
  logic [CW-1:0]  r_gtx_notintable;
  logic [CW-1:0]  r_gtx_disperr;

  // Data-path outputs
  logic [DW-1:0]  r_rx_data;
  logic           r_rx_valid;

  // LMFC signals
  logic [7:0] lmfc_counter; // LMFC counter width is 8 bits to accommodate the maximum number of beats per multiframe

  // Lane alignment offsets
  logic                latency_monitor_rst_n;
  logic [3*L-1:0]      lane_frame_align;

  //-------------------------------------------------------------------------
  // Buffer release logic
  //-------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      buffer_release_opp <= 1'b0;
    end else if (lmfc_counter == BUFFER_DELAY) begin
      buffer_release_opp <= 1'b1;
    end else begin
      buffer_release_opp <= 1'b0;
    end
  end

  always_comb begin
    all_buffers_ready = &buffer_ready_n;
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      buffer_release_n <= 1'b1;
    end else if (buffer_release_opp) begin
      buffer_release_n <= all_buffers_ready;
    end
  end

  // Output validity after buffer release
  logic buffer_release_dly;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      buffer_release_dly <= 1'b0;
    end else begin
      buffer_release_dly <= ~buffer_release_n;
    end
  end

  assign r_rx_valid = buffer_release_dly;

  //-------------------------------------------------------------------------
  // Input pipeline stage for GTX signals
  //-------------------------------------------------------------------------
  pipeline_stage #(
    .DATA_WIDTH(DW + 3*CW),
    .PIPE_DEPTH(1)
  ) input_pipeline (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .data_i  ({gtx_data_i, gtx_charisk_i, gtx_notintable_i, gtx_disperr_i}),
    .data_o  ({r_gtx_data, r_gtx_charisk, r_gtx_notintable, r_gtx_disperr})
  );

  //-------------------------------------------------------------------------
  // LMFC Generation
  //-------------------------------------------------------------------------
  lmfc #(
    .PARALLEL_OCTETS       (PARALLEL_OCTETS),
    .BEATS_PER_MULTIFRAME  (BEATS_PER_MULTIFRAME)
  ) i_lmfc (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .sysref_i      (sysref_i),
    .lmfc_clk_o    (lmfc_clk_o),
    .lmfc_counter_o(lmfc_counter)
  );

  //-------------------------------------------------------------------------
  // Frame marking
  //-------------------------------------------------------------------------
  frame_mark #(
    .PARALLEL_OCTETS (PARALLEL_OCTETS),
    .F               (F),
    .K               (K)
  ) i_frame_mark (
    .clk_i    (clk_i),
    .rst_ni   (buffer_release_dly),
    .sof_o    (rx_sof_o),
    .eof_o    (rx_eof_o),
    .somf_o   (rx_somf_o),
    .eomf_o   (rx_eomf_o)
  );

  //-------------------------------------------------------------------------
  // Primary Control
  //-------------------------------------------------------------------------

  ctrl #(
    .L       (L),
    .LINKS   (LINKS)
  ) i_ctrl (
    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni),
    .gtx_ready_i              (gtx_ready_i),
    .cgs_detected_i           (cgs_detected),
    .lmfc_clk_i               (lmfc_clk_o),
    .frame_align_err_thresh_i (),
    .gtx_notintable_i         (gtx_notintable_i),
    .gtx_disperr_i            (gtx_disperr_i),
    .rx_reset_gt_o            (rx_reset_gt_o),
    .gtx_en_char_align_o      (gtx_en_char_align_o),
    .cgs_rst_o                (cgs_rst),
    .ifs_rst_o                (ifs_rst),
    .sync_o                   (sync_o),
    .latency_monitor_rst_n_o  (latency_monitor_rst_n),
    .lane_disable_i           ({L{1'b0}}),
    .link_disable_i           ({LINKS{1'b0}})
  );

  //-------------------------------------------------------------------------
  // Data Path Instances
  //-------------------------------------------------------------------------
  genvar lane;
  generate
    for (lane = 0; lane < L; lane++) begin : gen_data_path
      localparam int DS = DATA_WIDTH;
      localparam int CS = PARALLEL_OCTETS;

      data_path #(
        .PARALLEL_OCTETS  (PARALLEL_OCTETS),
        .DATA_WIDTH       (DATA_WIDTH),
        .DESCRAMBLING     (DESCRAMBLING)
      ) i_data_path (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .gtx_data_i           (r_gtx_data[lane*DS +: DS]),
        .gtx_charisk_i        (r_gtx_charisk[lane*CS +: CS]),
        .gtx_notintable_i     (r_gtx_notintable[lane*CS +: CS]),
        .gtx_disperr_i        (r_gtx_disperr[lane*CS +: CS]),
        .cgs_reset_i          (cgs_rst[lane]),
        .ifs_reset_i          (ifs_rst[lane]),
        .buffer_release_ni    (buffer_release_n),
        .data_o               (r_rx_data[lane*DS +: DS]),
        .buffer_ready_no      (buffer_ready_n[lane]),
        .ifs_start_o          (ifs_start[lane]),
        .cgs_detected_o       (cgs_detected[lane]),
        .octet_align_o        (lane_frame_align[lane*3 +: 3])
      );
    end
  endgenerate

  //-------------------------------------------------------------------------
  // Output pipeline stage
  //-------------------------------------------------------------------------
  pipeline_stage #(
    .DATA_WIDTH            (DW+1),
    .PIPE_DEPTH            (1)
  ) output_pipeline (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .data_i  ({r_rx_data, r_rx_valid}),
    .data_o  ({rx_data_o, rx_valid_o})
  );

  //-------------------------------------------------------------------------
  // Lane Latency Monitor
  //-------------------------------------------------------------------------
  // Delay ifs_start for alignment into monitor
  logic [L-1:0] ifs_start_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni)
      ifs_start_q <= '0;
    else
      ifs_start_q <= ifs_start;
  end

  lane_latency_monitor #(
    .L                (L),
    .PARALLEL_OCTETS  (PARALLEL_OCTETS)
  ) i_lane_latency_monitor (
    .clk_i                   (clk_i),
    .rst_ni                  (latency_monitor_rst_n),
    .lane_ready_i            (ifs_start_q),
    .lane_frame_align_i      (lane_frame_align),
    .lane_latency_o          (),
    .lane_latency_ready_o    ()
  );

endmodule
