#===============================================
# top.tcl
# Batch entry-point for Vivado BD-based flow
#===============================================

# 0) Determine script directory for relative paths
proc get_script_folder {} {
    set script_path [file normalize [info script]]
    return [file dirname $script_path]
}
set script_folder [get_script_folder]

# 1) Parse '-run' flag
set do_run 0
if {[lsearch -exact $::argv "-run"] != -1} {
    set do_run 1
}

# 2) Project settings
set proj_name    "implementation_example"
set proj_dir     "./build/"
set part         "xczu19eg-ffvc1760-3-e"   ;# your target part
set board        ""                        ;# optional board name

# 3) Open or create project
if {[llength [get_projects -quiet]] == 0} {
    create_project $proj_name $proj_dir -part $part -force
    if {$board ne ""} {
        set_property board_part $board [current_project]
    }
} else {
    open_project "${proj_name}.xpr"
}

# 4) IP repositories → tell Vivado where to find your custom repos, then refresh
set ip_repo_list [list \
    "./ip_repo/jesd204b_rx_ip" \
]
set_property ip_repo_paths [join $ip_repo_list ";"] [current_project]
update_ip_catalog

# 5) Define your IP configurations
#    Each entry: { <ip_name> <vendor> <library> <version> <instance_name> <config_list> }
#    - config_list is itself a Tcl list of “CONFIG.<PARAM> <VALUE> …”
set ip_configs [list \
    [list axis_dwidth_converter  xilinx.com ip 1.1  axis_dwconv_32_128  [list CONFIG.M_TDATA_NUM_BYTES 16  CONFIG.S_TDATA_NUM_BYTES 4]] \
    [list axis_clock_converter   xilinx.com ip 1.1  axis_clkconv_128     [list CONFIG.TDATA_NUM_BYTES    16]] \
]

# 6) Create each IP and apply its parameters
foreach ip_info $ip_configs {
    # unpack fields
    set ip_name      [lindex $ip_info 0]   ;
    set ip_vendor    [lindex $ip_info 1]   ;
    set ip_library   [lindex $ip_info 2]   ;
    set ip_version   [lindex $ip_info 3]   ;
    set inst_name    [lindex $ip_info 4]   ;
    set cfg_list     [lindex $ip_info 5]   ;

    # Create the IP in the project
    create_ip -name $ip_name \
              -vendor $ip_vendor \
              -library $ip_library \
              -version $ip_version \
              -module_name $inst_name

    # Apply configuration parameters
    set_property -dict $cfg_list [get_ips $inst_name]
}

# 7) Add RTL sources (including block-design wrappers) before BD reconstruction
foreach src_file [glob -nocomplain ./source/*] {
    add_files -norecurse $src_file
}
update_compile_order -fileset sources_1

# 8) Source & build block design
source [file join $script_folder bd/block_design.tcl]

# 9) Add constraints
foreach xdc_file [glob -nocomplain ./constraints/*.xdc] {
    add_files -fileset constrs_1 -norecurse $xdc_file
}

# 10) Optionally run synthesis and implementation
if {$do_run} {
    launch_runs synth_1 -jobs 6;            wait_on_run synth_1
    launch_runs impl_1 -to_step write_bitstream;   wait_on_run impl_1
}