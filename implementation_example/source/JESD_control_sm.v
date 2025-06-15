//----------------------------------------------------------------------------
// Title : Support Level Module
// Project : JESD204
//----------------------------------------------------------------------------
// File : jesd204_support.v
//----------------------------------------------------------------------------

//
//----------------------------------------------------------------------------

`timescale 1ns / 1ps

//(* DowngradeIPIdentifiedWarnings = "yes" *)
module jesd204_0_control #(
    parameter F_val = 4,         //configure F Value of JESD204B
    parameter K_val = 16,        //configure K value of JESD204B
    parameter scrambler_en = 0,  //1- Scrambler Enabled, 0 - Scrambler Disabled
    parameter active_lanes = 8'b00000001, //[7:0] = 255, all lanes are active. if lanes [x:0] should be active, set all bits in [x:0] to '1' 
    parameter jesd_subclass = 1,  //Select JESD SUBCLASS - 0,1,2
    parameter param_count = 5     //Number of JESD Configuration parameters
)
(
    // input reset, // Reset

    // Input resets (active high)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input master_reset, // Master Reset
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input rx_reset, // RX Reset
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input axi_reset, // AXI Reset
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    output reset_rx_jesd,
    output reset_axi_jesd_n,
//    input             m_axi_aclk,

//    input start_config, // Start Configuration
//    output done_config, // Done Configuration

    input				m_axi_aclk	// AXI Clock
    // input				m_axi_aresetn,	// AXI Reset
//    output [11:0]		m_axi_awaddr,	// AXI Write address
//    output			m_axi_awvalid,	// Write address valid
//    input				m_axi_awready,	// Write address ready
//    output [31:0]		m_axi_wdata,	// Write data
//    output [3:0]		m_axi_wstrb,	// Write strobes
//    output			m_axi_wvalid,	// Write valid
//    input				m_axi_wready,	// Write ready
//    input [1:0]		m_axi_bresp,	// Write response
//    input				m_axi_bvalid,	// Write response valid
//    output            m_axi_bready,
//    output [11:0]		m_axi_araddr,	// Read address
//    output			m_axi_arvalid,	// Read address valid
//    input				m_axi_arready,	// Read address ready
//    input [31:0]		m_axi_rdata,	// Read data
//    input [1:0]		m_axi_rresp,	// Read response
//    input				m_axi_rvalid,	// Read valid
//    output			m_axi_rready	// Read ready

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
  wire rx_reset_re     = (rx_reset && ~rx_reset_d);
  wire axi_reset_re    = (axi_reset && ~axi_reset_d);

  // Separate counters and pulse active signals for RX and AXI resets
  reg [12:0] reset_rx_counter = 0; // Need at least 13 bits for 4800 count
  reg [12:0] reset_axi_counter = 0; // Need at least 13 bits for 4800 count
  reg rx_pulse_active = 1'b0;
  reg axi_pulse_active = 1'b0;

  always @(posedge m_axi_aclk) begin
    // RX reset pulse logic
    if (master_reset_re || rx_reset_re) begin
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
    if (master_reset_re || axi_reset_re) begin
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
  assign reset_rx_jesd      = rx_pulse_active;
  assign reset_axi_jesd_n   = ~axi_pulse_active;






//assign m_axi_wstrb = 4'b1111;
//// Assign values to output clocks
////  assign rx_core_clk_out = rx_core_clk_in;
//  // assign cpll_lock_out = &gt_cplllock;

//wire u_axi_done;
//wire u_axi_we;
//wire [11:0] u_axi_wraddr;
//wire [31:0] u_axi_wrdata;
//wire [31:0] axi_read_data;
//// wire done_config;

// jesd_configure #(
////    .F_val(F_val),        
////    .K_val(K_val),        
////    .scrambler_en(scrambler_en),  
////    .active_lanes(active_lanes),  
////    .jesd_subclass(jesd_subclass),  
////    .param_count(param_count)     
// )
// jesd_configure_global(
//    .reset(rx_areset_config),
//    .axi_clk(m_axi_aclk),
//    .start_config(start_config),
//    //User AXI write ports
//    .axi_done(u_axi_done),
//    .axi_we(u_axi_we),
//    .axi_wraddr(u_axi_wraddr),
//    .axi_wrdata(u_axi_wrdata),
//    .done_config(done_config)
// );
    
//usr_axi_ipif usr_axi (
//  // System AXI interface (output from module)
//  .s_axi_aclk(m_axi_aclk), 	        // AXI Clock
//  .s_axi_aresetn(reset_axi_jesd_n),	// AXI Reset
//  .s_axi_awaddr(m_axi_awaddr),	    // AXI Write address
//  .s_axi_awvalid(m_axi_awvalid),	// Write address valid
//  .s_axi_awready(m_axi_awready),	// Write address ready
//  .s_axi_wdata(m_axi_wdata),	    // Write data
//  .s_axi_wstrb(),	    // Write strobes
//  .s_axi_wvalid(m_axi_wvalid),	    // Write valid
//  .s_axi_wready(m_axi_wready),	    // Write ready
//  .s_axi_bresp(m_axi_bresp),	    // Write response
//  .s_axi_bvalid(m_axi_bvalid),	    // Write response valid
//  .s_axi_bready(m_axi_bready),
//  .s_axi_araddr(m_axi_araddr),	    // Read address
//  .s_axi_arvalid(m_axi_arvalid),	// Read address valid
//  .s_axi_arready(m_axi_arready),	// Read address ready
//  .s_axi_rdata(m_axi_rdata),	    // Read data
//  .s_axi_rresp(m_axi_rresp),	    // Read response
//  .s_axi_rvalid(m_axi_rvalid),	    // Read valid
//  .s_axi_rready(m_axi_rready),	    // Read ready
//  // User AXI Interface
//  .u_axi_addr(u_axi_wraddr),			// AXI Address
//  .u_axi_rdce(u_axi_rdce), 			// READ Enable 
//  .u_axi_rddata(u_axi_rddata),		// READ Data
//  .u_axi_wrce(u_axi_we),  		// Write Enable 
//  .u_axi_wrdata(u_axi_wrdata),		// Write Data
//  .u_axi_done(u_axi_done)			// done for read or write 
  
//);




endmodule
