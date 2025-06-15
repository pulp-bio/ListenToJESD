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