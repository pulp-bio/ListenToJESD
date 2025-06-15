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
`timescale 1ns / 10ps
(* X_INTERFACE_PRIORITY_LIST = "xilinx.com:display_jesd204:jesd204_rx_bus_rtl:1.0" *)

module rx_wrapper#(
    parameter LINKS = 1,
    parameter L = 2,
    parameter DATA_WIDTH = 32,
    parameter F = 4,
    parameter K = 32,
    parameter DESCRAMBLING = 0
)(
    input wire clk,
    input wire rst_n,
    
    (* X_INTERFACE_MODE = "slave" *)
    input wire [31:0] gt0_rxdata,
    input wire [3:0]  gt0_rxcharisk,
    input wire [3:0]  gt0_rxdisperr,
    input wire [3:0]  gt0_rxnotintable,

    (* X_INTERFACE_MODE = "slave" *)
    input wire [31:0] gt1_rxdata,
    input wire [3:0]  gt1_rxcharisk,
    input wire [3:0]  gt1_rxdisperr,
    input wire [3:0]  gt1_rxnotintable,

    (* X_INTERFACE_MODE = "slave" *)
    input wire [31:0] gt2_rxdata,
    input wire [3:0]  gt2_rxcharisk,
    input wire [3:0]  gt2_rxdisperr,
    input wire [3:0]  gt2_rxnotintable,

    (* X_INTERFACE_MODE = "slave" *)
    input wire [31:0] gt3_rxdata,
    input wire [3:0]  gt3_rxcharisk,
    input wire [3:0]  gt3_rxdisperr,
    input wire [3:0]  gt3_rxnotintable,

    input wire sysref,
    input wire rx_reset_done,

    output wire [LINKS-1:0] sync,
    output wire gtx_en_char_align,
    output wire rx_reset_gt,
    
    //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 rx_intf TDATA" *)
    output wire [(DATA_WIDTH*L)-1:0] rx_data,
    //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 rx_intf TVALID" *)
    output wire rx_valid,
    
    output wire [3:0] rx_eof,
    output wire [3:0] rx_sof,
    output wire [3:0] rx_eomf,
    output wire [3:0] rx_somf
    );
    
    // Concatenate the RX data and control signals from both GTs
    // The module calculates 4 Octets in Parallel and hence the width is 3*Lanes

    wire [(DATA_WIDTH*L)-1:0] gtx_rxdata;
    wire [(4*L)-1:0] gtx_rxcharisk;
    wire [(4*L)-1:0] gtx_rxdisperr;
    wire [(4*L)-1:0] gtx_rxnotintable;

    generate
    if (L == 1) begin
      assign gtx_rxdata       = {gt0_rxdata};
      assign gtx_rxcharisk    = {gt0_rxcharisk};
      assign gtx_rxdisperr    = {gt0_rxdisperr};
      assign gtx_rxnotintable = {gt0_rxnotintable};
    end else if (L == 2) begin
      assign gtx_rxdata       = {gt1_rxdata,       gt0_rxdata};
      assign gtx_rxcharisk    = {gt1_rxcharisk,    gt0_rxcharisk};
      assign gtx_rxdisperr    = {gt1_rxdisperr,    gt0_rxdisperr};
      assign gtx_rxnotintable = {gt1_rxnotintable, gt0_rxnotintable};
    end else if (L == 3) begin
      assign gtx_rxdata       = {gt2_rxdata, gt1_rxdata, gt0_rxdata};
      assign gtx_rxcharisk    = {gt2_rxcharisk, gt1_rxcharisk, gt0_rxcharisk};
      assign gtx_rxdisperr    = {gt2_rxdisperr, gt1_rxdisperr, gt0_rxdisperr};
      assign gtx_rxnotintable = {gt2_rxnotintable, gt1_rxnotintable, gt0_rxnotintable};
    end else if (L == 4) begin
      assign gtx_rxdata       = {gt3_rxdata, gt2_rxdata, gt1_rxdata, gt0_rxdata};
      assign gtx_rxcharisk    = {gt3_rxcharisk, gt2_rxcharisk, gt1_rxcharisk, gt0_rxcharisk};
      assign gtx_rxnotintable = {gt3_rxnotintable, gt2_rxnotintable, gt1_rxnotintable, gt0_rxnotintable};
      assign gtx_rxdisperr    = {gt3_rxdisperr, gt2_rxdisperr, gt1_rxdisperr, gt0_rxdisperr};
    end else begin
      assign gtx_rxdata       = {L*DATA_WIDTH{1'b0}};
      assign gtx_rxcharisk    = {L*4{1'b0}};
      assign gtx_rxdisperr    = {L*4{1'b0}};
      assign gtx_rxnotintable = {L*4{1'b0}};
    end
  endgenerate

    rx #(
        .L(L),
        .LINKS(LINKS),
        .DATA_WIDTH(DATA_WIDTH),
        .F(F),
        .K(K),
        .DESCRAMBLING(DESCRAMBLING)
        )
        i_jesd_rx (
        .clk_i                (clk),
        .rst_ni               (rst_n),
        .gtx_data_i           (gtx_rxdata),
        .gtx_charisk_i        (gtx_rxcharisk),
        .gtx_notintable_i     (gtx_rxnotintable),
        .gtx_disperr_i        (gtx_rxdisperr),
        .sysref_i             (sysref),
        .gtx_ready_i          (rx_reset_done),
        .lmfc_clk_o           (),
        .sync_o               (sync),
        .rx_reset_gt_o        (rx_reset_gt),
        .gtx_en_char_align_o  (gtx_en_char_align),
        .rx_data_o            (rx_data),
        .rx_valid_o           (rx_valid),
        .rx_eof_o             (rx_eof),
        .rx_sof_o             (rx_sof),
        .rx_eomf_o            (rx_eomf),
        .rx_somf_o            (rx_somf)
    );
    
endmodule