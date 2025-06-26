//------------------------------------------------------------------------------
// Description:
//   CGS (Code Group Synchronization) State Machine for JESD204B.
//   Detects CGS sequences during link bring-up and verifies integrity.
//   Transitions through INIT, CHECK, and DATA states.
//   Tolerates up to 3 erroneous beats during CGS CHECK phase.
//
// Parameters:
//   PARALLEL_OCTETS - Number of octets processed in parallel.
//   CGS_TOLERANCE   - Number of Non CGS Beats Received after CGS Start.
//   CGS_HOLD_WINDOW = Numebr of CGS Beats Received after CGS Start
//
// Ports:
//   clk_i          - Clock input.
//   rst_ni         - Active-low synchronous reset.
//   char_cgs_i     - Indicates CGS character detected per lane.
//   char_error_i   - Indicates character errors per lane.
//   cgs_detected_o - Asserted when CGS is successfully acquired.
//------------------------------------------------------------------------------

module cgs #(
  parameter int PARALLEL_OCTETS = 4,
  parameter int CGS_TOLERANCE   = 4,
  parameter int CGS_HOLD_WINDOW = 4
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,
  input  logic [PARALLEL_OCTETS-1:0]   char_cgs_i,
  input  logic [PARALLEL_OCTETS-1:0]   char_error_i,
  output logic                         cgs_detected_o
);

  // FSM State Declaration
  typedef enum logic [1:0] {
    ST_INIT,
    ST_CHECK,
    ST_DATA
  } state_e;

  state_e state_q, state_d;

  // Internal Signals
  // Currently support tolerance and hold window of 16
  logic [3:0] beat_error_cnt_q, beat_error_cnt_d;
  logic [3:0] beat_cgs_cnt_q, beat_cgs_cnt_d;
  logic       beat_is_cgs;
  logic       beat_has_error;
  logic       beat_full_error;

  // Beat Detection Logic
  always_comb begin
    beat_is_cgs     = &char_cgs_i;
    beat_has_error  = |char_error_i;
    beat_full_error = &char_error_i;
  end

  // Next State Logic
  always_comb begin
    state_d = state_q;
    if (!rst_ni) begin
      state_d = ST_INIT;
    end else begin
      unique case (state_q)
        ST_INIT: begin
          if (beat_is_cgs) begin
            state_d = ST_CHECK;
          end
        end
        ST_CHECK: begin
          if (beat_has_error) begin
            if (beat_full_error || beat_error_cnt_q == CGS_TOLERANCE) begin
              state_d = ST_INIT;
            end 
          end else begin
              state_d = ST_DATA;    
          end
        end
        ST_DATA: begin
          if (beat_has_error) begin
            state_d = ST_CHECK;
          end
        end

        default: state_d = ST_INIT;
      endcase
    end
  end

  // FSM State and Error Counter Update
  always_comb begin
    beat_error_cnt_d = beat_error_cnt_q;
    beat_cgs_cnt_d   = beat_cgs_cnt_q;

    if (state_q == ST_INIT) begin
      beat_error_cnt_d = '0;
    end else if (beat_has_error) begin
      beat_error_cnt_d = beat_error_cnt_q + 1;
    end else begin
      beat_error_cnt_d = '0;
    end

    // beat_cgs_cnt logic
    if (state_q == ST_CHECK && beat_is_cgs) begin
      beat_cgs_cnt_d = beat_cgs_cnt_q + 1;
    end else begin
      beat_cgs_cnt_d = '0;
    end
  end


  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q          <= ST_INIT;
      beat_error_cnt_q <= '0;
      beat_cgs_cnt_q   <= '0;
    end else begin
      state_q <= state_d;
      beat_error_cnt_q <= beat_error_cnt_d;
      beat_cgs_cnt_q   <= beat_cgs_cnt_d;
    end
  end

  // CGS Detection Signal
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      cgs_detected_o <= 1'b0;
    end else begin
      unique case (state_q)
        ST_DATA: cgs_detected_o <= 1'b1;
        ST_INIT: cgs_detected_o <= 1'b0;
        default: cgs_detected_o <= cgs_detected_o;
      endcase
    end
  end

endmodule
