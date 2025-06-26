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
// Utils : Double Flop Synchronizer for Clock Domain Crossing

module double_flop_sync #(
    parameter WIDTH = 1
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [WIDTH-1:0] signal_i,
    output logic [WIDTH-1:0] signal_o
);
    logic [WIDTH-1:0] stage_one_sync;
    logic [WIDTH-1:0] stage_two_sync;

    always_ff @(posedge clk_i) begin
        if(~rst_ni) begin
            stage_one_sync <= '0;
            stage_two_sync <= '0;
        end else begin
            stage_one_sync <= signal_i;
            stage_two_sync <= stage_one_sync;
        end
    end
    
    assign signal_o = stage_two_sync;
endmodule