// ==============================================================================
// Module: mac_pe
// Description: Processing Element (PE) performing Multiply-Accumulate (MAC)
//              operation for CNN acceleration.
//
// Operation:
//   - Multiplies signed data_in by signed weight_in
//   - Accumulates product into acc_out when en is high
//   - Clears accumulator synchronously when clr_acc is high
//   - Resets asynchronously on active-low rst_n
// ==============================================================================

`timescale 1ns / 1ps

module mac_pe #(
    parameter int DATA_WIDTH   = 8,
    parameter int WEIGHT_WIDTH = 8,
    parameter int ACC_WIDTH    = 20
) (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          en,
    input  logic                          clr_acc,
    input  logic signed [DATA_WIDTH-1:0]   data_in,
    input  logic signed [WEIGHT_WIDTH-1:0] weight_in,
    output logic signed [ACC_WIDTH-1:0]    acc_out
);

    // Multiplication result (signed)
    logic signed [DATA_WIDTH+WEIGHT_WIDTH-1:0] mult_result;

    assign mult_result = data_in * weight_in;

    // Accumulator register logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= '0;
        end else if (en) begin
            if (clr_acc) begin
                acc_out <= '0;
            end else begin
                acc_out <= acc_out + mult_result;
            end
        end
    end

endmodule
