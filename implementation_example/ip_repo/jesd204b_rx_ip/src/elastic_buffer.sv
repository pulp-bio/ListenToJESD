//------------------------------------------------------------------------------
// Description:
//   Elastic buffer for JESD204B receiver. Provides FIFO buffering of TX_WIDTH-bit
//   input data with a depth of BUFFER_SIZE. Handles asynchronous reset and
//   ready/release control signaling.
//
// Parameters:
//   DATA_WIDTH   - Width of each data frame.
//   BUFFER_SIZE  - Number of words in the buffer.
//
// Ports:
//   clk_i        - Input clock signal.
//   rst_ni       - Active-low synchronous reset.
//   in_data_i    - Input data word.
//   out_data_o   - Output data word.
//   ready_ni     - Active-low signal to pause writes.
//   release_ni   - Active-low signal to pause reads.
//------------------------------------------------------------------------------

module elastic_buffer #(
  parameter int DATA_WIDTH    = 32,
  parameter int BUFFER_SIZE   = 128
) (
  input  logic              clk_i,
  input  logic              rst_ni,

  input  logic [DATA_WIDTH-1:0]  in_data_i,
  output logic [DATA_WIDTH-1:0]  out_data_o,

  input  logic              ready_ni,
  input  logic              release_ni
);

  // Address Width Calculation
  localparam int ADDR_WIDTH = $clog2(BUFFER_SIZE);

  // Internal buffer and pointers
  logic [ADDR_WIDTH-1:0] write_ptr_q;
  logic [ADDR_WIDTH-1:0] read_ptr_q;
  logic [DATA_WIDTH-1:0]   buffer [BUFFER_SIZE];

  // Write logic
  always_ff @(posedge clk_i) begin
    if (!rst_ni || ~ready_ni) begin
      write_ptr_q <= '0;
    end else begin
      buffer[write_ptr_q] <= in_data_i;
      write_ptr_q         <= write_ptr_q + 1;
    end
  end

  // Read logic
  logic [DATA_WIDTH-1:0] read_data_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni || release_ni) begin
      read_ptr_q   <= '0;
      read_data_q  <= '0;
    end else begin
      read_data_q  <= buffer[read_ptr_q];
      read_ptr_q   <= read_ptr_q + 1;
    end
  end

  assign out_data_o = read_data_q;

endmodule