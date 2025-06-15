//------------------------------------------------------------------------------
// Description:
//   Lane Latency Monitor for JESD204B.
//   Measures the number of beats (clock cycles) from system start until each
//   lane asserts readiness (e.g., CGS or data alignment complete).
//   Stores latency per lane and appends 3-bit alignment offset.
//
// Parameters:
//   LANES (L)         - Number of JESD lanes to monitor.
//   PARALLEL_OCTETS   - Number of octets per beat per lane (not directly used here).
//
// Ports:
//   clk_i                   - Clock input.
//   rst_ni                  - Active-low synchronous reset.
//   lane_ready_i            - Indicates per-lane readiness signal (e.g., CGS done).
//   lane_frame_align_i      - Per-lane 3-bit alignment offset (total: LANES*3 bits).
//   lane_latency_o          - Per-lane 14-bit latency info: {11-bit counter, 3-bit align}.
//   lane_latency_ready_o    - Indicates latency has been captured per lane.
//------------------------------------------------------------------------------

module lane_latency_monitor #(
  parameter int L               = 1,
  parameter int PARALLEL_OCTETS = 4
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,
  input  logic [L-1:0]         lane_ready_i,
  input  logic [L*3-1:0]       lane_frame_align_i,
  output logic [L*14-1:0]      lane_latency_o,
  output logic [L-1:0]         lane_latency_ready_o
);

  // Internal beat counter (max 4096 beats)
  localparam int BEAT_CNT_WIDTH = 12;
  logic [BEAT_CNT_WIDTH-1:0] beat_ctr;

  // Per-lane latency memory and capture status
  logic [BEAT_CNT_WIDTH-1:0] lane_latency_mem [L-1:0];
  logic [L-1:0]          lane_captured;

  // Beat Counter
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      beat_ctr <= '0;
    end else if (beat_ctr != {BEAT_CNT_WIDTH{1'b1}}) begin
      beat_ctr <= beat_ctr + 1;
    end
  end

  // Per-lane latency tracking
  genvar i;
  generate
    for (i = 0; i < L; i++) begin : gen_lane_latency
      always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
          lane_latency_mem[i] <= '0;
          lane_captured[i]    <= 1'b0;
        end else if (lane_ready_i[i] && !lane_captured[i]) begin
          lane_latency_mem[i] <= beat_ctr;
          lane_captured[i]    <= 1'b1;
        end
      end
    // Output Lane Latency Packing
      always_comb begin
        lane_latency_ready_o[i] = lane_captured[i];
        lane_latency_o[i*14 +: 14] = {lane_latency_mem[i], lane_frame_align_i[i*3 +: 3]};
      end
    end
  endgenerate

endmodule
