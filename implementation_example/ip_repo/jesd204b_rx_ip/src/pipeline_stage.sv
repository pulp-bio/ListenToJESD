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

module pipeline_stage #(
    parameter DATA_WIDTH = 8,
    parameter PIPE_DEPTH = 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic [DATA_WIDTH-1:0] data_i,

    output logic [DATA_WIDTH-1:0] data_o
);
    logic [DATA_WIDTH-1:0] data [0:PIPE_DEPTH-1];
    
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            // Reset all pipeline stages
            for (int i = 0; i < PIPE_DEPTH; i++) begin
                data[i] <= '0;
            end
        end else begin
            // Shift data through the pipeline
            data[0] <= data_i;
            for (int i = 1; i < PIPE_DEPTH; i++) begin
                data[i] <= data[i-1];
            end
        end
    end

    // Assign the last stage to the output
    assign data_o = data[PIPE_DEPTH-1];

endmodule