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

################################################################
# block_design.tcl
# Cleaned export for integration into top_run.tcl
################################################################

namespace eval _tcl {
  proc get_script_folder {} {
    set script_path [file normalize [info script]]
    return [file dirname $script_path]
  }
}
variable script_folder
set script_folder [_tcl::get_script_folder]

#---------------------------------------------------------------
# Variables & design setup
#---------------------------------------------------------------
# Design name for the block design;
# defaults to "design_1" if not set externally
variable jesd204b_rx_light
if {![info exists design_name]} {
  set design_name "design_1"
}

# Open or create the block design
if {[current_bd_design -quiet] eq ""} {
  create_bd_design $design_name
} elseif {[current_bd_design -quiet] ne $design_name} {
  open_bd_design $design_name
}

#---------------------------------------------------------------
# Reconstruct hierarchy and IP cells
#---------------------------------------------------------------
# Hierarchical cell: JESD_subsystem
proc create_hier_cell_JESD_subsystem { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_JESD_subsystem() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -type clk refclk_fabric_320
  create_bd_pin -dir I rx_sysref
  create_bd_pin -dir I rx_core_reset
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -from 0 -to 0 gt0_rx_Lane1_n
  create_bd_pin -dir I -type clk rx_quadclk
  create_bd_pin -dir I -from 0 -to 0 gt0_rx_Lane1_p
  create_bd_pin -dir I -from 0 -to 0 gt1_rx_Lane1_p
  create_bd_pin -dir I -from 0 -to 0 gt1_rx_Lane1_n
  create_bd_pin -dir O -from 0 -to 0 CE_gt_powergood
  create_bd_pin -dir O -from 0 -to 0 rx_sync
  create_bd_pin -dir I -from 0 -to 0 rx_block_rst
  create_bd_pin -dir O -from 63 -to 0 rx_data
  create_bd_pin -dir O rx_data_valid

  # Create instance: jesd204_phy_0, and set properties
  set jesd204_phy_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:jesd204_phy:4.0 jesd204_phy_0 ]
  set_property -dict [list \
    CONFIG.C_LANES {1} \
    CONFIG.C_PLL_SELECTION {2} \
    CONFIG.DRPCLK_FREQ {120} \
    CONFIG.GT_Line_Rate {12.8} \
    CONFIG.GT_Location {X0Y3} \
    CONFIG.GT_REFCLK_FREQ {320} \
    CONFIG.RX_GT_Line_Rate {12.8} \
    CONFIG.RX_GT_REFCLK_FREQ {320} \
    CONFIG.RX_PLL_SELECTION {2} \
    CONFIG.Rx_JesdVersion {0} \
    CONFIG.TransceiverControl {false} \
    CONFIG.Tx_JesdVersion {0} \
  ] $jesd204_phy_0


  # Create instance: jesd204_phy_1, and set properties
  set jesd204_phy_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:jesd204_phy:4.0 jesd204_phy_1 ]
  set_property -dict [list \
    CONFIG.C_LANES {1} \
    CONFIG.C_PLL_SELECTION {2} \
    CONFIG.DRPCLK_FREQ {120} \
    CONFIG.GT_Line_Rate {12.8} \
    CONFIG.GT_Location {X0Y6} \
    CONFIG.GT_REFCLK_FREQ {320} \
    CONFIG.RX_GT_Line_Rate {12.8} \
    CONFIG.RX_GT_REFCLK_FREQ {320} \
    CONFIG.RX_PLL_SELECTION {2} \
    CONFIG.Rx_JesdVersion {0} \
    CONFIG.SupportLevel {1} \
    CONFIG.TransceiverControl {true} \
    CONFIG.Tx_JesdVersion {0} \
  ] $jesd204_phy_1


  # Create instance: util_vector_logic_1, and set properties
  set util_vector_logic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_1 ]
  set_property CONFIG.C_SIZE {1} $util_vector_logic_1


  # Create instance: ila_0, and set properties
  set ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0 ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {9} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {64} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE5_WIDTH {4} \
    CONFIG.C_PROBE6_WIDTH {4} \
    CONFIG.C_PROBE7_WIDTH {4} \
    CONFIG.C_PROBE8_WIDTH {4} \
  ] $ila_0


  # Create instance: util_vector_logic_0, and set properties
  set util_vector_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0 ]
  set_property CONFIG.C_SIZE {1} $util_vector_logic_0


  # Create instance: jesd204b_rx_0, and set properties
  set jesd204b_rx_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:jesd204b_rx:1.0 jesd204b_rx_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net jesd204_phy_0_gt0_rx [get_bd_intf_pins jesd204_phy_0/gt0_rx] [get_bd_intf_pins jesd204b_rx_0/gt1]
  connect_bd_intf_net -intf_net jesd204_phy_1_gt0_rx [get_bd_intf_pins jesd204_phy_1/gt0_rx] [get_bd_intf_pins jesd204b_rx_0/gt0]

  # Create port connections
  connect_bd_net -net gt0_rx_Lane1_n_1 [get_bd_pins gt0_rx_Lane1_n] [get_bd_pins jesd204_phy_0/rxn_in]
  connect_bd_net -net gt0_rx_Lane1_p_1 [get_bd_pins gt0_rx_Lane1_p] [get_bd_pins jesd204_phy_0/rxp_in]
  connect_bd_net -net gt1_rx_Lane1_n_1 [get_bd_pins gt1_rx_Lane1_n] [get_bd_pins jesd204_phy_1/rxn_in]
  connect_bd_net -net gt1_rx_Lane1_p_1 [get_bd_pins gt1_rx_Lane1_p] [get_bd_pins jesd204_phy_1/rxp_in]
  connect_bd_net -net jesd204_phy_0_gt_powergood [get_bd_pins jesd204_phy_0/gt_powergood] [get_bd_pins util_vector_logic_1/Op1]
  connect_bd_net -net jesd204_phy_0_rx_reset_done [get_bd_pins jesd204_phy_0/rx_reset_done] [get_bd_pins util_vector_logic_0/Op1]
  connect_bd_net -net jesd204_phy_1_gt_powergood [get_bd_pins jesd204_phy_1/gt_powergood] [get_bd_pins util_vector_logic_1/Op2]
  connect_bd_net -net jesd204_phy_1_rx_reset_done [get_bd_pins jesd204_phy_1/rx_reset_done] [get_bd_pins util_vector_logic_0/Op2]
  connect_bd_net -net jesd204b_rx_0_gtx_en_char_align [get_bd_pins jesd204b_rx_0/gtx_en_char_align] [get_bd_pins jesd204_phy_1/rxencommaalign] [get_bd_pins jesd204_phy_0/rxencommaalign] [get_bd_pins ila_0/probe1]
  connect_bd_net -net jesd204b_rx_0_rx_data [get_bd_pins jesd204b_rx_0/rx_data] [get_bd_pins ila_0/probe3] [get_bd_pins rx_data]
  connect_bd_net -net jesd204b_rx_0_rx_eof [get_bd_pins jesd204b_rx_0/rx_eof] [get_bd_pins ila_0/probe5]
  connect_bd_net -net jesd204b_rx_0_rx_eomf [get_bd_pins jesd204b_rx_0/rx_eomf] [get_bd_pins ila_0/probe7]
  connect_bd_net -net jesd204b_rx_0_rx_reset_gt [get_bd_pins jesd204b_rx_0/rx_reset_gt] [get_bd_pins jesd204_phy_1/tx_reset_gt] [get_bd_pins jesd204_phy_1/rx_reset_gt] [get_bd_pins jesd204_phy_0/rx_reset_gt] [get_bd_pins jesd204_phy_0/tx_reset_gt] [get_bd_pins ila_0/probe2]
  connect_bd_net -net jesd204b_rx_0_rx_sof [get_bd_pins jesd204b_rx_0/rx_sof] [get_bd_pins ila_0/probe6]
  connect_bd_net -net jesd204b_rx_0_rx_somf [get_bd_pins jesd204b_rx_0/rx_somf] [get_bd_pins ila_0/probe8]
  connect_bd_net -net jesd204b_rx_0_rx_valid [get_bd_pins jesd204b_rx_0/rx_valid] [get_bd_pins ila_0/probe4] [get_bd_pins rx_data_valid]
  connect_bd_net -net jesd204b_rx_0_sync [get_bd_pins jesd204b_rx_0/sync] [get_bd_pins rx_sync] [get_bd_pins ila_0/probe0]
  connect_bd_net -net refclk_fabric_320_1 [get_bd_pins refclk_fabric_320] [get_bd_pins jesd204_phy_0/rx_core_clk] [get_bd_pins jesd204_phy_0/tx_core_clk] [get_bd_pins jesd204_phy_1/rx_core_clk] [get_bd_pins jesd204_phy_1/tx_core_clk] [get_bd_pins ila_0/clk] [get_bd_pins jesd204b_rx_0/clk]
  connect_bd_net -net rx_block_rst_1 [get_bd_pins rx_block_rst] [get_bd_pins jesd204b_rx_0/rst_n]
  connect_bd_net -net rx_core_reset_1 [get_bd_pins rx_core_reset] [get_bd_pins jesd204_phy_0/rx_sys_reset] [get_bd_pins jesd204_phy_0/tx_sys_reset] [get_bd_pins jesd204_phy_1/rx_sys_reset] [get_bd_pins jesd204_phy_1/tx_sys_reset]
  connect_bd_net -net rx_quadclk_1 [get_bd_pins rx_quadclk] [get_bd_pins jesd204_phy_0/qpll1_refclk] [get_bd_pins jesd204_phy_1/qpll1_refclk]
  connect_bd_net -net rx_sysref_1 [get_bd_pins rx_sysref] [get_bd_pins jesd204b_rx_0/sysref]
  connect_bd_net -net s_axi_aclk_1 [get_bd_pins s_axi_aclk] [get_bd_pins jesd204_phy_0/drpclk] [get_bd_pins jesd204_phy_1/drpclk]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins util_vector_logic_0/Res] [get_bd_pins jesd204b_rx_0/rx_reset_done]
  connect_bd_net -net util_vector_logic_1_Res [get_bd_pins util_vector_logic_1/Res] [get_bd_pins CE_gt_powergood]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ctrl_and_reset
proc create_hier_cell_ctrl_and_reset { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ctrl_and_reset() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type rst rx_rst
  create_bd_pin -dir O -type clk clk_out_120
  create_bd_pin -dir O -from 0 -to 0 -type rst axi_120_aresetn
  create_bd_pin -dir O -type rst reset_rx_jesd
  create_bd_pin -dir I -type clk refclk_fabric_320
  create_bd_pin -dir O -type clk clk_out_320
  create_bd_pin -dir O -from 0 -to 0 axi_80_aresetn
  create_bd_pin -dir O clk_out_80

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]
  set_property -dict [list \
    CONFIG.C_AUX_RST_WIDTH {1} \
    CONFIG.C_EXT_RST_WIDTH {1} \
  ] $proc_sys_reset_1


  # Create instance: proc_sys_reset_2, and set properties
  set proc_sys_reset_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_2 ]
  set_property -dict [list \
    CONFIG.C_AUX_RST_WIDTH {1} \
    CONFIG.C_EXT_RST_WIDTH {1} \
  ] $proc_sys_reset_2


  # Create instance: jesd204_0_control_0, and set properties
  set block_name jesd204_0_control
  set block_cell_name jesd204_0_control_0
  if { [catch {set jesd204_0_control_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $jesd204_0_control_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: vio_0, and set properties
  set vio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_0 ]
  set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {0} \
    CONFIG.C_NUM_PROBE_OUT {3} \
  ] $vio_0


  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKOUT1_DRIVES {Buffer} \
    CONFIG.CLKOUT1_JITTER {101.652} \
    CONFIG.CLKOUT1_MATCHED_ROUTING {false} \
    CONFIG.CLKOUT1_PHASE_ERROR {73.069} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {80} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT2_JITTER {93.838} \
    CONFIG.CLKOUT2_PHASE_ERROR {73.069} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {120} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLK_OUT1_PORT {clk_out_80} \
    CONFIG.CLK_OUT2_PORT {clk_out_120} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {3.750} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {15.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {10} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {1} \
    CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_0


  # Create instance: proc_sys_reset_3, and set properties
  set proc_sys_reset_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_3 ]
  set_property -dict [list \
    CONFIG.C_AUX_RST_WIDTH {1} \
    CONFIG.C_EXT_RST_WIDTH {1} \
  ] $proc_sys_reset_3


  # Create port connections
  connect_bd_net -net Net2 [get_bd_pins proc_sys_reset_2/interconnect_aresetn] [get_bd_pins axi_120_aresetn]
  connect_bd_net -net axi_reset [get_bd_pins vio_0/probe_out2] [get_bd_pins jesd204_0_control_0/axi_reset]
  connect_bd_net -net clk_120 [get_bd_pins clk_wiz_0/clk_out_120] [get_bd_pins clk_out_120] [get_bd_pins vio_0/clk] [get_bd_pins jesd204_0_control_0/m_axi_aclk] [get_bd_pins proc_sys_reset_2/slowest_sync_clk]
  connect_bd_net -net clk_320 [get_bd_pins refclk_fabric_320] [get_bd_pins clk_wiz_0/clk_in1] [get_bd_pins clk_out_320] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net clk_wiz_0_clk_out_80 [get_bd_pins clk_wiz_0/clk_out_80] [get_bd_pins proc_sys_reset_3/slowest_sync_clk] [get_bd_pins clk_out_80]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins proc_sys_reset_2/dcm_locked] [get_bd_pins proc_sys_reset_3/dcm_locked]
  connect_bd_net -net jesd204_0_control_0_reset_axi_jesd_n1 [get_bd_pins jesd204_0_control_0/reset_axi_jesd_n] [get_bd_pins proc_sys_reset_1/ext_reset_in] [get_bd_pins proc_sys_reset_2/ext_reset_in] [get_bd_pins proc_sys_reset_3/ext_reset_in]
  connect_bd_net -net master_reset [get_bd_pins vio_0/probe_out0] [get_bd_pins jesd204_0_control_0/master_reset]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins proc_sys_reset_1/peripheral_aresetn] [get_bd_pins rx_rst]
  connect_bd_net -net proc_sys_reset_3_interconnect_aresetn [get_bd_pins proc_sys_reset_3/interconnect_aresetn] [get_bd_pins axi_80_aresetn]
  connect_bd_net -net rx_core_reset [get_bd_pins jesd204_0_control_0/reset_rx_jesd] [get_bd_pins reset_rx_jesd]
  connect_bd_net -net rx_reset [get_bd_pins vio_0/probe_out1] [get_bd_pins jesd204_0_control_0/rx_reset]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports
  set gt0_rx_Lane1_p [ create_bd_port -dir I -from 0 -to 0 gt0_rx_Lane1_p ]
  set gt0_rx_Lane1_n [ create_bd_port -dir I -from 0 -to 0 gt0_rx_Lane1_n ]
  set rx_quadclk [ create_bd_port -dir I rx_quadclk ]
  set rx_sysref [ create_bd_port -dir I rx_sysref ]
  set rx_sync [ create_bd_port -dir O -from 0 -to 0 rx_sync ]
  set CE_gt_powergood [ create_bd_port -dir O -from 0 -to 0 CE_gt_powergood ]
  set refclk_fabric_320 [ create_bd_port -dir I -type clk -freq_hz 320000000 refclk_fabric_320 ]
  set gt1_rx_Lane1_n [ create_bd_port -dir I -from 0 -to 0 gt1_rx_Lane1_n ]
  set gt1_rx_Lane1_p [ create_bd_port -dir I -from 0 -to 0 gt1_rx_Lane1_p ]

  # Create instance: ctrl_and_reset
  create_hier_cell_ctrl_and_reset [current_bd_instance .] ctrl_and_reset

  # Create instance: JESD_subsystem
  create_hier_cell_JESD_subsystem [current_bd_instance .] JESD_subsystem

  # Create instance: jesd_stream_flattene_0, and set properties
  set block_name jesd_stream_flattener_wrapper
  set block_cell_name jesd_stream_flattene_0
  if { [catch {set jesd_stream_flattene_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $jesd_stream_flattene_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ila_0, and set properties
  set ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0 ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {2} \
    CONFIG.C_PROBE0_WIDTH {256} \
  ] $ila_0


  # Create port connections
  connect_bd_net -net JESD_subsystem_CE_gt_powergood [get_bd_pins JESD_subsystem/CE_gt_powergood] [get_bd_ports CE_gt_powergood]
  connect_bd_net -net JESD_subsystem_rx_data [get_bd_pins JESD_subsystem/rx_data] [get_bd_pins jesd_stream_flattene_0/s_axis_tdata]
  connect_bd_net -net JESD_subsystem_rx_data_valid [get_bd_pins JESD_subsystem/rx_data_valid] [get_bd_pins jesd_stream_flattene_0/s_axis_tvalid]
  connect_bd_net -net JESD_subsystem_rx_open_sync [get_bd_pins JESD_subsystem/rx_sync] [get_bd_ports rx_sync]
  connect_bd_net -net clk_320 [get_bd_ports refclk_fabric_320] [get_bd_pins ctrl_and_reset/refclk_fabric_320]
  connect_bd_net -net ctrl_and_reset_axi_80_aresetn [get_bd_pins ctrl_and_reset/axi_80_aresetn] [get_bd_pins jesd_stream_flattene_0/m_axis_aresetn]
  connect_bd_net -net ctrl_and_reset_clk_out_80 [get_bd_pins ctrl_and_reset/clk_out_80] [get_bd_pins jesd_stream_flattene_0/m_axis_aclk] [get_bd_pins ila_0/clk]
  connect_bd_net -net ctrl_and_reset_clk_out_120 [get_bd_pins ctrl_and_reset/clk_out_120] [get_bd_pins JESD_subsystem/s_axi_aclk]
  connect_bd_net -net ctrl_and_reset_rx_rst [get_bd_pins ctrl_and_reset/rx_rst] [get_bd_pins JESD_subsystem/rx_block_rst] [get_bd_pins jesd_stream_flattene_0/s_axis_aresetn]
  connect_bd_net -net gt0_rx_Lane1_n_1 [get_bd_ports gt0_rx_Lane1_n] [get_bd_pins JESD_subsystem/gt0_rx_Lane1_n]
  connect_bd_net -net gt0_rx_Lane1_p_1 [get_bd_ports gt0_rx_Lane1_p] [get_bd_pins JESD_subsystem/gt0_rx_Lane1_p]
  connect_bd_net -net gt1_rx_Lane1_n_1 [get_bd_ports gt1_rx_Lane1_n] [get_bd_pins JESD_subsystem/gt1_rx_Lane1_n]
  connect_bd_net -net gt1_rx_Lane1_p_1 [get_bd_ports gt1_rx_Lane1_p] [get_bd_pins JESD_subsystem/gt1_rx_Lane1_p]
  connect_bd_net -net jesd_stream_flattene_0_m_axis_tdata [get_bd_pins jesd_stream_flattene_0/m_axis_tdata] [get_bd_pins ila_0/probe0]
  connect_bd_net -net jesd_stream_flattene_0_m_axis_tvalid [get_bd_pins jesd_stream_flattene_0/m_axis_tvalid] [get_bd_pins ila_0/probe1]
  connect_bd_net -net refclk_fabric_320_1 [get_bd_pins ctrl_and_reset/clk_out_320] [get_bd_pins JESD_subsystem/refclk_fabric_320] [get_bd_pins jesd_stream_flattene_0/s_axis_aclk]
  connect_bd_net -net rx_core_reset [get_bd_pins ctrl_and_reset/reset_rx_jesd] [get_bd_pins JESD_subsystem/rx_core_reset]
  connect_bd_net -net rx_quadclk_1 [get_bd_ports rx_quadclk] [get_bd_pins JESD_subsystem/rx_quadclk]
  connect_bd_net -net rx_sysref_1 [get_bd_ports rx_sysref] [get_bd_pins JESD_subsystem/rx_sysref]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}

create_root_design ""
#---------------------------------------------------------------
# Finalize design
#---------------------------------------------------------------
validate_bd_design
save_bd_design