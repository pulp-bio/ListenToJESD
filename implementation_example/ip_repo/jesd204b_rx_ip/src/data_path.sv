//------------------------------------------------------------------------------
// Description:
//   JESD204B Receiver Data Path Module.
//   Performs character validation, CGS detection, octet alignment, ILAS detection,
//   optional descrambling, and buffering.
//
// Parameters:
//   PARALLEL_OCTETS  - Number of parallel octets received per cycle.
//   DATA_WIDTH       - Width of the incoming data word.
//   DESCRAMBLING     - Enable descrambler logic (1 to enable).
//   BUFFER_SIZE      - Size of the elastic buffer in words.
//
// Ports:
//   clk_i             - Clock input.
//   rst_ni            - Active-low synchronous reset.
//   gtx_data_i        - Raw GTX data input.
//   gtx_charisk_i     - Character valid signals from GTX.
//   gtx_notintable_i  - Not-in-table error indicator.
//   gtx_disperr_i     - Disparity error indicator.
//   cgs_reset_i       - Reset from CGS FSM.
//   ifs_reset_i       - Reset signal for initial frame sequence (active high).
//   buffer_release_ni - Active-low signal to release data from buffer.
//   data_o            - Output data.
//   buffer_ready_no   - Active-low signal, buffer ready for new data.
//   ifs_start_o       - Indicates end of initial CGS sequence.
//   cgs_detected_o    - CGS detection signal.
//   octet_align_o     - Octet alignment index.
//------------------------------------------------------------------------------

module data_path #(
  parameter int PARALLEL_OCTETS   = 4,
  parameter int DATA_WIDTH        = 32,
  parameter bit DESCRAMBLING      = 0,
  parameter int BUFFER_SIZE       = 128
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,

  input  logic [DATA_WIDTH-1:0]         gtx_data_i,
  input  logic [PARALLEL_OCTETS-1:0]    gtx_charisk_i,
  input  logic [PARALLEL_OCTETS-1:0]    gtx_notintable_i,
  input  logic [PARALLEL_OCTETS-1:0]    gtx_disperr_i,

  input  logic                     cgs_reset_i,
  input  logic                     ifs_reset_i,
  input  logic                     buffer_release_ni,

  output logic [DATA_WIDTH-1:0]    data_o,
  output logic                     buffer_ready_no,
  output logic                     ifs_start_o,
  output logic                     cgs_detected_o,
  output logic [2:0]               octet_align_o
);

  //--------------------------------------------------------------------------
  // Character Decoding and Classification
  //--------------------------------------------------------------------------

  // All K28 Characters have the same 5-bit LSB value ('d28) with different
  // header bits. The header bits are used to identify the character.

  localparam [4:0] K28_VALUE  = 5'd28;
  localparam [2:0] K28_HEADER = 3'd5;

  logic [7:0]                    char [PARALLEL_OCTETS-1:0];
  logic [PARALLEL_OCTETS-1:0]    char_valid;
  logic [PARALLEL_OCTETS-1:0]    char_error;
  logic [PARALLEL_OCTETS-1:0]    char_cgs;
  logic [PARALLEL_OCTETS-1:0]    char_is_k28;
  logic [PARALLEL_OCTETS-1:0]    char_is_unexpected;

  genvar i;
  generate
    for (i = 0; i < PARALLEL_OCTETS; i++) begin : gtx_char_decode
      assign char[i]        = gtx_data_i[i*8 +: 8];
      assign char_valid[i]  = ~(gtx_notintable_i[i] | gtx_disperr_i[i]);

      always_comb begin
        char_error[i]         = ~char_valid[i];
        char_cgs[i]           = 1'b0;
        char_is_k28[i]        = 1'b0;
        char_is_unexpected[i] = 1'b0;

        if (gtx_charisk_i[i] && char_valid[i]) begin
          if (char[i][4:0] == K28_VALUE) begin
            char_is_k28[i] = 1'b1;
            if (char[i][7:5] == K28_HEADER)
              char_cgs[i] = 1'b1;
          end else begin
            char_is_unexpected[i] = 1'b1;
          end
        end
      end
    end
  endgenerate

  //--------------------------------------------------------------------------
  // Initial Frame Sequence Start Detection
  //--------------------------------------------------------------------------

  logic frame_is_cgs, frame_is_error;

  assign frame_is_cgs  = &char_cgs;
  assign frame_is_error = |char_error;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      ifs_start_o <= 1'b0;
    end else if (ifs_reset_i) begin
      ifs_start_o <= 1'b0;
    end else if (!frame_is_cgs && !frame_is_error) begin
      ifs_start_o <= 1'b1;
    end
  end

  //--------------------------------------------------------------------------
  // Octet Alignment Index Logic
  // "Supports 4 parallel octets hardcoded for now , and hence align_idx is 3 bits"
  //--------------------------------------------------------------------------

  logic align_found_flag;
  logic [2:0] align_idx_d, align_idx_q;

  always_comb begin
    align_found_flag = 1'b0;
    align_idx_d = 3'd0;

    for (int lane = 0; lane < PARALLEL_OCTETS; lane++) begin
      if (!align_found_flag && !char_cgs[lane]) begin
        align_found_flag = 1'b1;
        align_idx_d = lane[2:0];
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      align_idx_q <= 3'd0;
    end else if (!ifs_start_o) begin
      align_idx_q <= align_idx_d;
    end
  end

  assign octet_align_o = align_idx_q;

  //--------------------------------------------------------------------------
  // Octet Alignment
  //--------------------------------------------------------------------------

  logic [DATA_WIDTH-1:0]      aligned_data;
  logic [DATA_WIDTH-1:0]    aligned_char_is_k28;

  octet_align #(
    .PARALLEL_OCTETS   (PARALLEL_OCTETS),
    .DATA_WIDTH        (DATA_WIDTH)
  ) i_octet_align (
    .clk_i             (clk_i),
    .rst_ni            (rst_ni),
    .in_data_i         (gtx_data_i),
    .in_char_is_k28_i  (char_is_k28),
    .octet_align_idx_i (octet_align_o),
    .out_data_o        (aligned_data),
    .out_char_is_k28_o (aligned_char_is_k28)
  );

  //--------------------------------------------------------------------------
  // Descrambling Logic
  //--------------------------------------------------------------------------

logic [DATA_WIDTH-1:0] descrambled_data;

descrambler #(
  .DATA_WIDTH   (DATA_WIDTH)
) i_descrambler (
  .clk_i             (clk_i),
  .rst_ni            (data_out_valid),
  .descramble_en_i   (DESCRAMBLING),
  .data_i            (aligned_data),
  .data_o            (descrambled_data)
);

  //--------------------------------------------------------------------------
  // Elastic Buffer
  //--------------------------------------------------------------------------

  logic data_out_valid;

  assign buffer_ready_no = ~data_out_valid;

  elastic_buffer #(
    .DATA_WIDTH   (DATA_WIDTH),
    .BUFFER_SIZE  (BUFFER_SIZE)
  ) i_elastic_buffer (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .in_data_i    (descrambled_data),
    .out_data_o   (data_o),
    .ready_ni     (data_out_valid),
    .release_ni   (buffer_release_ni)
  );

  //--------------------------------------------------------------------------
  // ILAS Monitoring
  //--------------------------------------------------------------------------

  ilas_monitor #(
    .PARALLEL_OCTETS (PARALLEL_OCTETS),
    .DATA_WIDTH      (DATA_WIDTH)
  ) i_ilas_monitor (
    .clk_i          (clk_i),
    .rst_ni         (ifs_start_o),  // Active-low reset so this disables ILAS until IFS ends
    .data_i         (aligned_data),
    .char_is_k28_i  (aligned_char_is_k28),
    .data_ready_o   (data_out_valid)
  );

  //--------------------------------------------------------------------------
  // Code Group Synchronization (CGS)
  //--------------------------------------------------------------------------

  cgs #(
    .PARALLEL_OCTETS (PARALLEL_OCTETS)
  ) i_cgs (
    .clk_i          (clk_i),
    .rst_ni         (~cgs_reset_i),
    .char_cgs_i     (char_cgs),
    .char_error_i   (char_error),
    .cgs_detected_o (cgs_detected_o)
  );

endmodule
