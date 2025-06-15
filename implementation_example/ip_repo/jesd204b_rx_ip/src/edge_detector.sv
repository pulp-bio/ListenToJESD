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