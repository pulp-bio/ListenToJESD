# Copyright 2025 ETH Zurich
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 0.51 (the "License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.
#
# Authors:
# Soumyo Bhattacharjee  <sbhattacharj@student.ethz.ch>

# XDC file for the specified pin assignments


### Sysref (differential)
# --- we use the Quad Clock for the sysref
set_property -dict {PACKAGE_PIN AL15 IOSTANDARD LVDS} [get_ports rx_sysref_p]
set_property -dict {PACKAGE_PIN AM15 IOSTANDARD LVDS} [get_ports rx_sysref_n]

### QUAD Clock
# --- needed for the jesd_phy cpll_refclk
set_property PACKAGE_PIN AK11 [get_ports rx_quadclk_n]
set_property PACKAGE_PIN AK12 [get_ports rx_quadclk_p]
create_clock -period 3.125 -name rx_quadclk [get_ports rx_quadclk_p]
create_generated_clock -name refclk_fabric_320 -source [get_ports rx_quadclk_p] -multiply_by 1 [get_nets refclk_fabric_320]


### OUT Sync Signal for JESD (differential)
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVDS} [get_ports rx_sync_p]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVDS} [get_ports rx_sync_n]


set_property C_CLK_INPUT_FREQ_HZ 120000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
