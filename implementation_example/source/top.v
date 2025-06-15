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

`timescale 1 ps / 1 ps

module top
   ( 
  input [0:0]    gt0_rx_Lane1_n,
  input [0:0]    gt0_rx_Lane1_p,
  input [0:0]    gt1_rx_Lane1_n,
  input [0:0]    gt1_rx_Lane1_p,
  input rx_quadclk_n,
  input rx_quadclk_p,
  input rx_sysref_p,
  
  input  rx_sysref_n,
  output rx_sync_p,
  output rx_sync_n
  );
  wire rx_sync;
  wire rx_sysref;
  wire refclk_fabric;
//  wire refclk_fabric_120;
  wire CE_gt_powergood; 
IBUFDS IBUFDS_sysref(
    .O(rx_sysref),
    .I(rx_sysref_p),
    .IB(rx_sysref_n)
); 

OBUFDS OBUFDS_sync(
    .O(rx_sync_p),
    .OB(rx_sync_n),
    .I(rx_sync)
);
 
IBUFDS_GTE4 IBUFDS_inst0 (
    .O      (rx_quadclk),
    .ODIV2  (refclk_fabric),
    .CEB    (1'b0),
    .I      (rx_quadclk_p),
    .IB     (rx_quadclk_n)
);

//BUFG_GT bufg_refclk (
//    .O      (refclk_fabric_120),
//    .I      (refclk_fabric),
//    .CE     (CE_gt_powergood),
//    .CEMASK (0),
//    .CLR    (0),
//    .CLRMASK(0),
//    .DIV    (002)
//); 

BUFG_GT bufg_refclk_320 (
    .O      (refclk_fabric_320),
    .I      (refclk_fabric),
    .CE     (CE_gt_powergood),
    .CEMASK (0),
    .CLR    (0),
    .CLRMASK(0),
    .DIV    (000)
); 

  design_1 design_1_i
       (.gt0_rx_Lane1_n(gt0_rx_Lane1_n[0]),
        .gt0_rx_Lane1_p(gt0_rx_Lane1_p[0]),
        .gt1_rx_Lane1_n(gt1_rx_Lane1_n[0]),
        .gt1_rx_Lane1_p(gt1_rx_Lane1_p[0]),
        .rx_quadclk(rx_quadclk),
        .rx_sysref(rx_sysref),
        .rx_sync(rx_sync),
        .refclk_fabric_320(refclk_fabric_320),
        .CE_gt_powergood(CE_gt_powergood)
        );
        
        
        
        
        
endmodule
