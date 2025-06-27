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
// Federico Villani  <villanif@ethz.ch>
// Soumyo Bhattacharjee  <sbhattacharj@student.ethz.ch>
//
//----------------------------------------------------------------------------
// Title : Reset Pulse Generator
// Project : JESD204
//----------------------------------------------------------------------------
// File : reset_pulse_generator.v
//----------------------------------------------------------------------------
// Description: 
// This module generates fixed-length reset pulses for JESD204 RX and AXI 
// interfaces. It detects rising edges on input reset signals and generates
// 4800 clock cycle pulses for proper reset sequencing.
//----------------------------------------------------------------------------

//
//----------------------------------------------------------------------------
`timescale 1ns / 1ps

module reset_pulse_generator (
    input m_axi_aclk, // AXI Clock
    // Input resets (active high)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input master_reset, // Master Reset
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input rx_reset, // RX Reset
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input axi_reset, // AXI Reset
    
    // Output resets
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    output reset_rx_jesd,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    output reset_axi_jesd_n

);

  localparam integer PULSE_LEN = 4800;

  // Rising edge detection for inputs
  reg master_reset_d = 1'b0;
  reg rx_reset_d = 1'b0;
  reg axi_reset_d = 1'b0;

  always @(posedge m_axi_aclk) begin
    master_reset_d <= master_reset;
    rx_reset_d <= rx_reset;
    axi_reset_d <= axi_reset;
  end

  wire master_reset_re = (master_reset && ~master_reset_d);

  // Separate counters and pulse active signals for RX and AXI resets
  reg [12:0] reset_rx_counter = 0; // Need at least 13 bits for 4800 count
  reg [12:0] reset_axi_counter = 0; // Need at least 13 bits for 4800 count
  reg rx_pulse_active = 1'b0;
  reg axi_pulse_active = 1'b0;

  always @(posedge m_axi_aclk) begin
    // RX reset pulse logic
    if (master_reset_re || (rx_reset && ~rx_reset_d)) begin
      reset_rx_counter <= PULSE_LEN;
      rx_pulse_active <= 1'b1;
    end else if (rx_pulse_active) begin
      if (reset_rx_counter > 0) begin
        reset_rx_counter <= reset_rx_counter - 1;
      end else begin
        rx_pulse_active <= 1'b0;
      end
    end

    // AXI reset pulse logic
    if (master_reset_re || (axi_reset && ~axi_reset_d)) begin
      reset_axi_counter <= PULSE_LEN;
      axi_pulse_active <= 1'b1;
    end else if (axi_pulse_active) begin
      if (reset_axi_counter > 0) begin
        reset_axi_counter <= reset_axi_counter - 1;
      end else begin
        axi_pulse_active <= 1'b0;
      end
    end
  end

  // Assign reset outputs
  assign reset_rx_jesd    = rx_pulse_active;
  assign reset_axi_jesd_n = ~axi_pulse_active;

endmodule