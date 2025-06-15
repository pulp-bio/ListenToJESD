//------------------------------------------------------------------------------
// Description:
//   JESD204B Receiver Control FSM.
//   Manages physical-layer reset, CGS and IFS resets, character alignment enable,
//   and synchronization across multiple links and lanes.
//
// Parameters:
//   LANES (L)   - Number of parallel JESD lanes.
//   LINKS       - Number of independent links.
//   PARALLEL_OCTETS - Number of parallel octets per lane.
//
// Ports:
//   clk_i                     - Clock input.
//   rst_ni                    - Active-low synchronous reset.
//   lane_disable_i            - Per-lane disable signals.
//   link_disable_i            - Per-link disable signals.
//   gtx_ready_i               - Indicates PHY is ready.
//   cgs_detected_i            - Per-lane CGS detection flags.
//   lmfc_clk_i                - Local multiframe clock.
//   frame_align_err_thresh_i  - Per-lane frame-align error threshold enable.
//   gtx_notintable_i          - Per-lane GT not-intable error signals.
//   gtx_disperr_i             - Per-lane GT disperr error signals.
//
//   rx_reset_gt_o             - Reset signal for GT receiver.
//   gtx_en_char_align_o       - Enable character alignment in PHY.
//   cgs_rst_o                 - Per-lane CGS reset signals.
//   ifs_rst_o                 - Per-lane IFS (initial frame sequence) resets.
//   sync_o                    - Link-level sync outputs.
//   latency_monitor_rst_n_o   - Active-low reset for latency monitor.
//------------------------------------------------------------------------------

module ctrl #(
  parameter int L               = 1,
  parameter int LINKS           = 1,
  parameter int PARALLEL_OCTETS = 4
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic [L-1:0]           lane_disable_i,
  input  logic [LINKS-1:0]       link_disable_i,

  input  logic                   gtx_ready_i,
  input  logic [L-1:0]           cgs_detected_i,

  input  logic                   lmfc_clk_i,
  input  logic [L-1:0]           frame_align_err_thresh_i,

  input logic [L*PARALLEL_OCTETS-1:0]  gtx_notintable_i,
  input logic [L*PARALLEL_OCTETS-1:0]  gtx_disperr_i,

  output logic                   rx_reset_gt_o,
  output logic                   gtx_en_char_align_o,
  output logic [L-1:0]           cgs_rst_o,
  output logic [L-1:0]           ifs_rst_o,
  output logic [L-1:0]           sync_o,
  output logic                   latency_monitor_rst_n_o
);

  //----------------------------------------------------------------------------
  // FSM State Declaration
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ST_RESET,
    ST_WAIT_FOR_PHY,
    ST_CGS,
    ST_SYNCED
  } state_e;

  state_e state_q, state_d;

  //----------------------------------------------------------------------------
  // Internal Registers
  //----------------------------------------------------------------------------
  logic [L-1:0]        cgs_rst_q;
  logic [L-1:0]        ifs_rst_q;
  logic [LINKS-1:0]    sync_q;
  logic                en_align_q;

  logic                rx_reset_gt_q;
  logic                rx_reset_gt_flag;
  logic [3:0]          rx_reset_gen_ctr_q;  // Upto 15 cycles

  logic [7:0]          state_stable_ctr_q;
  logic                state_stable_flag;

  logic                latency_monitor_rst_n_q;

  //----------------------------------------------------------------------------
  // Output Assignments
  //----------------------------------------------------------------------------
  assign cgs_rst_o               = cgs_rst_q;
  assign ifs_rst_o               = ifs_rst_q;
  assign sync_o                  = sync_q;
  assign gtx_en_char_align_o     = en_align_q;
  assign rx_reset_gt_o           = rx_reset_gt_q;
  assign latency_monitor_rst_n_o = latency_monitor_rst_n_q;

  //----------------------------------------------------------------------------
  // GT Receiver Reset Generation
  //----------------------------------------------------------------------------
  localparam int RX_RESET_GEN_CTR_CYCLE = 4'd3;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      rx_reset_gen_ctr_q  <= RX_RESET_GEN_CTR_CYCLE;
      rx_reset_gt_flag    <= 1'b0;
    end else if (rx_reset_gen_ctr_q != 4'd0) begin
      rx_reset_gen_ctr_q  <= rx_reset_gen_ctr_q - 1;
    end else begin
      rx_reset_gt_flag    <= 1'b1;
    end
  end

  //----------------------------------------------------------------------------
  // Main Control FSM Outputs
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      cgs_rst_q               <= {L{1'b1}};
      ifs_rst_q               <= {L{1'b1}};
      sync_q                  <= {LINKS{1'b1}};
      latency_monitor_rst_n_q <= 1'b0;
      rx_reset_gt_q           <= 1'b0;
    end else begin
      case (state_q)
        ST_RESET: begin
          cgs_rst_q               <= {L{1'b1}};
          ifs_rst_q               <= {L{1'b1}};
          sync_q                  <= {LINKS{1'b1}};
          latency_monitor_rst_n_q <= 1'b0;
          rx_reset_gt_q           <= 1'b1;
        end

        ST_WAIT_FOR_PHY: begin
          rx_reset_gt_q <= 1'b0;
        end

        ST_CGS: begin
          cgs_rst_q <= lane_disable_i;
          sync_q    <= link_disable_i;
        end

        ST_SYNCED: begin
          if (lmfc_clk_i) begin
            ifs_rst_q               <= lane_disable_i;
            sync_q                  <= {LINKS{1'b1}};
            latency_monitor_rst_n_q <= 1'b1;
          end
        end

        default: begin
          // nothing
        end
      endcase
    end
  end

  //----------------------------------------------------------------------------
  // State Stability Flag Logic
  // The state is "stable" when the required conditions are met:
  // - In RESET, we assume it's stable.
  // - In WAIT_FOR_PHY, phy_ready must be asserted.
  // - In CGS, all lanes must either be ready (cgs_ready) or disabled.
  // - In SYNCHRONIZED, if frame alignment error reset is enabled, then errors must be absent.
  //----------------------------------------------------------------------------
  always_comb begin
    unique case (state_q)
      ST_RESET:        state_stable_flag = 1'b1;
      ST_WAIT_FOR_PHY: state_stable_flag = gtx_ready_i;
      ST_CGS:          state_stable_flag = &(cgs_detected_i | lane_disable_i);
      ST_SYNCED:       state_stable_flag = 1'b1;
      default:         state_stable_flag = 1'b0;
    endcase
  end

  //----------------------------------------------------------------------------
  // Incorrect Transmission Detection and Flag Generation
  //----------------------------------------------------------------------------
  localparam int INCORRECT_TRANS_TOLERANCE = 12'hFFF;
  logic [11:0] incorrect_transmission_ctr_q;
  logic       incorrect_transmission_flag;

  logic notintable_error;
  logic disperr_error;

  assign notintable_error = |gtx_notintable_i;
  assign disperr_error    = |gtx_disperr_i;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        incorrect_transmission_ctr_q <= 12'h0;
    end else begin 
        if (notintable_error || disperr_error) begin
            incorrect_transmission_ctr_q <= incorrect_transmission_ctr_q + 1;
        end
    end 
  end

  assign incorrect_transmission_flag = (incorrect_transmission_ctr_q == INCORRECT_TRANS_TOLERANCE);  

  //----------------------------------------------------------------------------
  // Stable State Counter & Next-State Condition
  //----------------------------------------------------------------------------
  logic [7:0] stable_ctr_limit_q;
  logic       stable_ctr_limit_flag;
  logic       goto_next_state;

  localparam int STABLE_CTR_LIMIT_CGS = 8'h0F; // 15 cycles for CGS
  localparam int STABLE_CTR_LIMIT_SYNCED = 8'h05; // 5 cycles for SYNCED

  always_comb begin
    stable_ctr_limit_q     = (state_q == ST_CGS) ? STABLE_CTR_LIMIT_CGS : STABLE_CTR_LIMIT_SYNCED;
    stable_ctr_limit_flag  = (state_stable_ctr_q == stable_ctr_limit_q);
    goto_next_state        = stable_ctr_limit_flag || (state_q == ST_SYNCED);
  end

  always_ff @(posedge clk_i ) begin
    if (!rst_ni) begin
      state_stable_ctr_q <= '0;
    end else if (state_stable_flag) begin
      if (stable_ctr_limit_flag) begin
        state_stable_ctr_q <= '0;
      end else begin
        state_stable_ctr_q <= state_stable_ctr_q + 1;
      end
    end else begin
      state_stable_ctr_q <= '0;
    end
  end

  //----------------------------------------------------------------------------
  // Character Alignment Enable
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      en_align_q <= 1'b0;
    end else begin
      en_align_q <= (state_q == ST_CGS);
    end
  end

  //----------------------------------------------------------------------------
  // FSM Next-State Logic
  //----------------------------------------------------------------------------
  always_comb begin
    unique case (state_q)
      ST_RESET:        state_d = rx_reset_gt_flag ? ST_WAIT_FOR_PHY : ST_RESET;
      ST_WAIT_FOR_PHY: state_d = ST_CGS;
      ST_CGS:          state_d = ST_SYNCED;
      ST_SYNCED:       state_d = incorrect_transmission_flag ? ST_RESET : ST_SYNCED;
      default:         state_d = ST_RESET;
    endcase
  end

  //----------------------------------------------------------------------------
  // FSM State Register
  //----------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= ST_RESET;
    end else if (goto_next_state) begin
      state_q <= state_d;
    end
  end

endmodule
