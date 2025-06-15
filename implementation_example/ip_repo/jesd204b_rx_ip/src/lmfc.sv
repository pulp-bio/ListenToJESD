//------------------------------------------------------------------------------
// Description:
//   Local Multi-Frame Clock (LMFC) Generator for JESD204B.
//   Tracks SYSREF signal to align internal frame counters to LMFC boundaries.
//   Generates LMFC clock pulse and an 8-bit counter for frame alignment.
//
// Parameters:
//   PARALLEL_OCTETS        - Number of octets processed in parallel.
//   BEATS_PER_MULTIFRAME   - Number of beats per multiframe (Octets Per Multiframe / Octets Processed in Parallel) .
//
// Ports:
//   clk_i               - Clock input.
//   rst_ni              - Active-low synchronous reset.
//   sysref_i            - SYSREF pulse input.
//   lmfc_clk_o          - LMFC pulse output.
//   lmfc_counter_o      - LMFC counter output (0 to BEATS_PER_MULTIFRAME-1).
//------------------------------------------------------------------------------

module lmfc #(
  parameter int PARALLEL_OCTETS = 4,
  parameter int BEATS_PER_MULTIFRAME = 64
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic sysref_i,

  output logic lmfc_clk_o,
  output logic [7:0] lmfc_counter_o
);

  // Internal Signals
  //FIXME : Sysref is a pulse and not single shot version
  logic sysref_capture;
  logic sysref_pulse;
  logic sysref_detected;
  logic [7:0] lmfc_counter;
  logic       lmfc_active;
  logic       lmfc_clk;

  // Synchronize SYSREF pulse into clk_i domain
  double_flop_sync #(
    .WIDTH(1)
  ) i_sysref_sync (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .signal_i (sysref_i),
    .signal_o (sysref_capture)
  );

  // Detect rising edge of SYSREF
  edge_detector i_sysref_edge (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .signal_i        (sysref_capture),
    .posedge_pulse_o (sysref_pulse),
    .negedge_pulse_o ()
  );

  // SYSREF seen
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      sysref_detected <= 1'b0;
    end else if (sysref_pulse) begin
      sysref_detected <= 1'b1;
    end
  end

  // LMFC Counter Logic
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      lmfc_counter <= 8'd0;
      lmfc_active  <= 1'b0;
    end else if (sysref_pulse && !sysref_detected) begin
      lmfc_counter <= 8'd0; // LMFC Offset Configuration Possible Here
      lmfc_active  <= 1'b1;
    end else if (lmfc_counter == (BEATS_PER_MULTIFRAME - 1)) begin
      lmfc_counter <= 8'd0;
    end else begin
      lmfc_counter <= lmfc_counter + 1;
    end
  end

  // LMFC Clock Pulse Generation
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      lmfc_clk <= 1'b0;
    end else if (lmfc_active) begin
      lmfc_clk <= (lmfc_counter == 0);
    end else begin
      lmfc_clk <= 1'b0;
    end
  end

  // Outputs
  assign lmfc_clk_o     = lmfc_clk;
  assign lmfc_counter_o = lmfc_counter;

endmodule
