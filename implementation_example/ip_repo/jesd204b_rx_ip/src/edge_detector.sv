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
// Utils : Edge Detector for Rising and Falling Edges

module edge_detector (
    input logic clk_i,
    input logic rst_ni,
    input logic signal_i,
    output logic posedge_pulse_o,
    output logic negedge_pulse_o
);
    logic signal_sync;
    
    always_ff @(posedge clk_i) begin
        if (~rst_ni) begin
            signal_sync <= 1'b0;
        end else begin
            signal_sync <= signal_i;
        end
    end

    assign posedge_pulse_o = ~signal_sync & signal_i;
    assign negedge_pulse_o = signal_sync & ~signal_i;

endmodule