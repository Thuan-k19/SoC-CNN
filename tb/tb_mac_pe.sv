// ==============================================================================
// Testbench: tb_mac_pe
// Description: Self-checking testbench for mac_pe module
// ==============================================================================

`timescale 1ns / 1ps

module tb_mac_pe;

    // Parameters
    localparam int DATA_WIDTH   = 8;
    localparam int WEIGHT_WIDTH = 8;
    localparam int ACC_WIDTH    = 20;
    localparam real CLK_PERIOD  = 10.0; // 100 MHz clock

    // DUT Signals
    logic                          clk;
    logic                          rst_n;
    logic                          en;
    logic                          clr_acc;
    logic signed [DATA_WIDTH-1:0]   data_in;
    logic signed [WEIGHT_WIDTH-1:0] weight_in;
    logic signed [ACC_WIDTH-1:0]    acc_out;

    // Testbench Variables
    int error_count;
    int test_count;
    logic signed [ACC_WIDTH-1:0] expected_acc;

    // Instantiate Device Under Test (DUT)
    mac_pe #(
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .clr_acc(clr_acc),
        .data_in(data_in),
        .weight_in(weight_in),
        .acc_out(acc_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // Helper task to check accumulator output
    task check_result(input string test_name, input logic signed [ACC_WIDTH-1:0] expected);
        test_count++;
        @(negedge clk); // sample after posedge update
        if (acc_out !== expected) begin
            $display("[FAIL] %s: Expected %0d, got %0d at time %0t", 
                     test_name, expected, acc_out, $time);
            error_count++;
        end else begin
            $display("[PASS] %s: acc_out = %0d as expected", test_name, acc_out);
        end
    endtask

    // Main Test Sequence
    initial begin
        // Setup waveform dumping for GTKWave
        $dumpfile("mac_pe_tb.vcd");
        $dumpvars(0, tb_mac_pe);

        // Initialize variables
        error_count  = 0;
        test_count   = 0;
        expected_acc = 0;
        rst_n        = 1'b0;
        en           = 1'b0;
        clr_acc      = 1'b0;
        data_in      = '0;
        weight_in    = '0;

        $display("------------------------------------------------------------");
        $display("Starting MAC PE Verification Testbench");
        $display("------------------------------------------------------------");

        // ------------------------------------------------------------
        // Test 1: Asynchronous Reset Test
        // ------------------------------------------------------------
        #(CLK_PERIOD * 1.5);
        if (acc_out !== 20'sd0) begin
            $display("[FAIL] Reset Test: acc_out is not 0 during reset. Got: %0d", acc_out);
            error_count++;
        end else begin
            $display("[PASS] Reset Test: acc_out initialized to 0.");
        end
        test_count++;

        // Deassert reset
        @(negedge clk);
        rst_n = 1'b1;

        // ------------------------------------------------------------
        // Test 2: Basic Positive and Negative MAC Operations
        // ------------------------------------------------------------
        $display("\n--- Test 2: Standard MAC Operation Sequence ---");
        en = 1'b1;
        clr_acc = 1'b0;

        // Step 2.1: 10 * 5 = 50 -> Acc = 50
        data_in   = 8'sd10;
        weight_in = 8'sd5;
        expected_acc = 20'sd50;
        check_result("Step 2.1 (10 * 5)", expected_acc);

        // Step 2.2: -12 * 3 = -36 -> Acc = 50 - 36 = 14
        data_in   = -8'sd12;
        weight_in = 8'sd3;
        expected_acc = 20'sd14;
        check_result("Step 2.2 (-12 * 3)", expected_acc);

        // Step 2.3: -4 * -6 = 24 -> Acc = 14 + 24 = 38
        data_in   = -8'sd4;
        weight_in = -8'sd6;
        expected_acc = 20'sd38;
        check_result("Step 2.3 (-4 * -6)", expected_acc);

        // ------------------------------------------------------------
        // Test 3: Corner Cases (Max Positive and Negative Multiplication)
        // ------------------------------------------------------------
        $display("\n--- Test 3: Corner Cases (Min/Max 8-bit Signed) ---");
        // Clear accumulator first
        clr_acc = 1'b1;
        data_in = 8'sd0;
        weight_in = 8'sd0;
        expected_acc = 20'sd0;
        check_result("Clear for Corner Cases", expected_acc);
        clr_acc = 1'b0;

        // Max Positive: 127 * 127 = 16129
        data_in   = 8'sd127;
        weight_in = 8'sd127;
        expected_acc = 20'sd16129;
        check_result("Corner 127 * 127", expected_acc);

        // Min Negative * Max Positive: -128 * 127 = -16256 -> Acc = 16129 - 16256 = -127
        data_in   = -8'sd128;
        weight_in = 8'sd127;
        expected_acc = 20'sd16129 - 20'sd16256;
        check_result("Corner -128 * 127", expected_acc);

        // Min Negative * Min Negative: -128 * -128 = 16384 -> Acc = -127 + 16384 = 16257
        data_in   = -8'sd128;
        weight_in = -8'sd128;
        expected_acc = expected_acc + 20'sd16384;
        check_result("Corner -128 * -128", expected_acc);

        // ------------------------------------------------------------
        // Test 4: Accumulation Depth & Overflow Resistance Test
        // ------------------------------------------------------------
        $display("\n--- Test 4: Accumulation Depth (16 iterations of max value) ---");
        clr_acc = 1'b1;
        check_result("Clear before depth test", 20'sd0);
        clr_acc = 1'b0;

        expected_acc = 20'sd0;
        data_in   = 8'sd127;
        weight_in = 8'sd127; // +16129 each step
        for (int i = 1; i <= 16; i++) begin
            expected_acc += 20'sd16129;
            check_result($sformatf("Accumulation loop step %0d", i), expected_acc);
        end

        // ------------------------------------------------------------
        // Test 5: Enable Signal (en = 0 holds state)
        // ------------------------------------------------------------
        $display("\n--- Test 5: Enable Control Check ---");
        en = 1'b0;
        data_in   = 8'sd50;
        weight_in = 8'sd20;
        // Output should hold previous expected_acc
        check_result("Disabled en (acc holds value)", expected_acc);

        // ------------------------------------------------------------
        // Test 6: Synchronous Clear (clr_acc)
        // ------------------------------------------------------------
        $display("\n--- Test 6: Synchronous Clear Test ---");
        en = 1'b1;
        clr_acc = 1'b1;
        expected_acc = 20'sd0;
        check_result("Synchronous clr_acc assertion", expected_acc);

        // Resume operation after clear
        clr_acc = 1'b0;
        data_in = 8'sd7;
        weight_in = 8'sd8;
        expected_acc = 20'sd56;
        check_result("Resume after clear (7 * 8)", expected_acc);

        // ------------------------------------------------------------
        // Final Summary
        // ------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("Verification Summary: Total Tests = %0d, Errors = %0d", 
                 test_count, error_count);
        $display("------------------------------------------------------------");

        if (error_count == 0) begin
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! <<<\n");
        end else begin
            $display(">>> SIMULATION FAILED WITH %0d ERRORS! <<<\n", error_count);
        end

        $finish;
    end

endmodule
