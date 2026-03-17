`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 04:16:05 PM
// Design Name: 
// Module Name: tb_drift_proof
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ps / 1ps  // picosecond resolution for precise clock drift
//////////////////////////////////////////////////////////////////////////////
// tb_drift_proof.v — PROOF that Temperature Compensation Works
//
// WHAT THIS TESTBENCH DOES:
//   1. Generates a DRIFTING clock that changes frequency with temperature
//      (simulating a real crystal oscillator)
//   2. Feeds this drifting clock to TWO seconds generators:
//      - COMPENSATED:   uses corrected_count from the drift LUT
//      - UNCOMPENSATED: always counts to fixed 100,000,000
//   3. Compares both against a PERFECT reference clock
//   4. Shows that the compensated clock stays accurate while the
//      uncompensated clock drifts
//
// THE KEY INSIGHT:
//   In simulation, we CAN create a perfect reference clock (unlike hardware).
//   We make the oscillator clock drift according to the crystal model,
//   and show that the LUT correction cancels out that drift.
//
// SIMULATION IS ACCELERATED:
//   Instead of counting to 100,000,000 (which would take forever in sim),
//   we use a scale factor. The math still works identically.
//
// EXPECTED OUTPUT:
//   At 25°C: Both clocks match reference         → 0 error
//   At 50°C: Uncompensated drifts, compensated OK → only uncomp has error
//   At 70°C: Uncompensated drifts MORE, comp OK   → larger uncomp error
//   At 80°C: Maximum drift, compensated still OK   → proves the model
//////////////////////////////////////////////////////////////////////////////

module tb_drift_proof;

// ============================================================
// CRYSTAL MODEL PARAMETERS (same as Python script)
// ============================================================
real F_NOMINAL  = 100_000_000.0;   // 100 MHz nominal
real T_TURNOVER = 25.0;            // Turnover temperature
real BETA_PPM   = -0.035;          // ppm/°C² (AT-cut crystal)

// ============================================================
// SCALE FACTOR — speed up simulation
// ============================================================
// Instead of counting to 100M, we count to SCALE_COUNT.
// All corrections are scaled proportionally.
localparam SCALE_FACTOR = 1000;             // 1000× speedup
localparam SCALE_COUNT  = 100_000;          // 100M / 1000
// Nominal half-period in ps: 1e12 / (2 * 100e6) = 5000 ps
localparam NOMINAL_HALF_PERIOD_PS = 5000;

// ============================================================
// TEMPERATURE STIMULUS
// ============================================================
integer test_temp;        // Current test temperature (°C)
integer temp_index;       // LUT index = temp - 20

// ============================================================
// DRIFTING CLOCK GENERATOR
// ============================================================
// Simulates a crystal whose frequency changes with temperature
// f_actual = f_nominal × (1 + β × (T-T0)² × 1e-6)
// half_period = 1e12 / (2 × f_actual) in picoseconds

real drift_ppm;
real f_actual;
integer half_period_ps;    // Drifting clock half-period

reg drifting_clk;
initial drifting_clk = 0;

always begin
    #(half_period_ps) drifting_clk = ~drifting_clk;
end

// Update drift when temperature changes
task set_temperature;
    input integer temp_c;
    real dt;
    begin
        test_temp = temp_c;
        temp_index = temp_c - 20;
        dt = temp_c - T_TURNOVER;
        drift_ppm = BETA_PPM * dt * dt;
        f_actual = F_NOMINAL * (1.0 + drift_ppm * 1.0e-6);
        half_period_ps = 1_000_000_000_000.0 / (2.0 * f_actual);
        
        $display("  Set temperature = %0d°C", temp_c);
        $display("    Drift        = %f ppm", drift_ppm);
        $display("    f_actual     = %f Hz", f_actual);
        $display("    Half-period  = %0d ps (nominal = %0d ps)", 
                 half_period_ps, NOMINAL_HALF_PERIOD_PS);
    end
endtask

// ============================================================
// PERFECT REFERENCE CLOCK (does not drift)
// ============================================================
reg ref_clk;
initial ref_clk = 0;
always #(NOMINAL_HALF_PERIOD_PS) ref_clk = ~ref_clk;

// ============================================================
// DRIFT LUT (instantiate the actual RTL)
// ============================================================
reg  [5:0]  lut_index;
wire [35:0] lut_corrected_count;

drift_lut_table u_lut (
    .clk(drifting_clk),
    .temp_index(lut_index),
    .corrected_count(lut_corrected_count)
);

// Scale the corrected count by SCALE_FACTOR
// Original: UQ28.8 format, ~100,000,000.xxx
// Scaled:   divide by SCALE_FACTOR → ~100,000.xxx
// Keep the fractional bits
wire [35:0] corrected_scaled = lut_corrected_count / SCALE_FACTOR;

// ============================================================
// COMPENSATED SECONDS GENERATOR (uses LUT)
// ============================================================
reg  comp_rst;
wire comp_pulse;

seconds_generator u_comp (
    .clk(drifting_clk),
    .rst(comp_rst),
    .corrected_count(corrected_scaled),
    .one_sec_pulse(comp_pulse)
);

// ============================================================
// UNCOMPENSATED SECONDS GENERATOR (fixed count)
// ============================================================
// Always counts to SCALE_COUNT — no temperature correction
reg [27:0] uncomp_counter;
reg        uncomp_pulse;
reg        uncomp_rst;

always @(posedge drifting_clk) begin
    if (uncomp_rst) begin
        uncomp_counter <= 0;
        uncomp_pulse   <= 0;
    end else begin
        uncomp_pulse <= 0;
        if (uncomp_counter >= SCALE_COUNT - 1) begin
            uncomp_counter <= 0;
            uncomp_pulse   <= 1;
        end else
            uncomp_counter <= uncomp_counter + 1;
    end
end

// ============================================================
// REFERENCE SECONDS GENERATOR (perfect clock, fixed count)
// ============================================================
reg [27:0] ref_counter;
reg        ref_pulse;
reg        ref_rst;

always @(posedge ref_clk) begin
    if (ref_rst) begin
        ref_counter <= 0;
        ref_pulse   <= 0;
    end else begin
        ref_pulse <= 0;
        if (ref_counter >= SCALE_COUNT - 1) begin
            ref_counter <= 0;
            ref_pulse   <= 1;
        end else
            ref_counter <= ref_counter + 1;
    end
end

// ============================================================
// PULSE COUNTERS — count how many "seconds" each produces
// ============================================================
integer comp_ticks;
integer uncomp_ticks;
integer ref_ticks;

always @(posedge drifting_clk) begin
    if (comp_rst) comp_ticks <= 0;
    else if (comp_pulse) comp_ticks <= comp_ticks + 1;
end

always @(posedge drifting_clk) begin
    if (uncomp_rst) uncomp_ticks <= 0;
    else if (uncomp_pulse) uncomp_ticks <= uncomp_ticks + 1;
end

always @(posedge ref_clk) begin
    if (ref_rst) ref_ticks <= 0;
    else if (ref_pulse) ref_ticks <= ref_ticks + 1;
end

// ============================================================
// TIME TRACKING — measure actual elapsed time
// ============================================================
integer comp_time_ps;      // Time at each compensated pulse
integer uncomp_time_ps;    // Time at each uncompensated pulse
integer ref_time_ps;       // Time at each reference pulse
integer sim_start_time;

// Track timestamps at pulse edges
always @(posedge drifting_clk) begin
    if (comp_pulse)   comp_time_ps <= $time;
    if (uncomp_pulse) uncomp_time_ps <= $time;
end
always @(posedge ref_clk) begin
    if (ref_pulse)    ref_time_ps <= $time;
end

// ============================================================
// MAIN TEST SEQUENCE
// ============================================================

integer i;
integer wait_ticks;
real comp_error_us, uncomp_error_us;
real expected_period_ps, actual_period_ps;

initial begin
    $display("");
    $display("================================================================");
    $display("  DRIFT CORRECTION PROOF — Testbench");
    $display("================================================================");
    $display("  Crystal model: df/f0 = %.4f × (T - %.1f)² ppm", BETA_PPM, T_TURNOVER);
    $display("  Nominal freq:  %.0f Hz", F_NOMINAL);
    $display("  Scale factor:  %0d× (count to %0d instead of 100M)", SCALE_FACTOR, SCALE_COUNT);
    $display("================================================================");
    $display("");

    // Initialize
    comp_rst   = 1;
    uncomp_rst = 1;
    ref_rst    = 1;
    lut_index  = 0;
    
    // Start at 25°C
    set_temperature(25);
    
    // Let clock stabilize
    repeat (10) @(posedge drifting_clk);
    
    // Release resets
    comp_rst   = 0;
    uncomp_rst = 0;
    ref_rst    = 0;
    
    // Update LUT index
    lut_index = 5;  // 25 - 20 = 5
    repeat (5) @(posedge drifting_clk);  // Let LUT register
    
    sim_start_time = $time;

    // -------------------------------------------------------
    // TEST TEMPERATURES: 25, 35, 45, 55, 65, 75, 80°C
    // At each temperature, run for enough ticks to accumulate
    // measurable drift, then compare all three counters.
    // -------------------------------------------------------
    
    $display("");
    $display("  Running tests at different temperatures...");
    $display("  (Each test runs 100 scaled-seconds)");
    $display("");
    $display("  %-6s | %-10s | %-10s | %-10s | %-14s | %-14s | %s",
             "Temp", "Drift(ppm)", "Ref Ticks", "Comp Ticks", "Uncomp Ticks", "Comp Error", "Uncomp Error");
    $display("  %-6s | %-10s | %-10s | %-10s | %-14s | %-14s | %s",
             "------", "----------", "----------", "----------", "--------------", "--------------", "------------");

    // Test each temperature
    for (i = 0; i < 7; i = i + 1) begin
        case (i)
            0: set_temperature(25);
            1: set_temperature(35);
            2: set_temperature(45);
            3: set_temperature(55);
            4: set_temperature(65);
            5: set_temperature(75);
            6: set_temperature(80);
        endcase
        
        lut_index = test_temp - 20;
        
        // Reset all counters for clean measurement
        comp_rst   = 1;
        uncomp_rst = 1;
        ref_rst    = 1;
        repeat (5) @(posedge drifting_clk);
        comp_rst   = 0;
        uncomp_rst = 0;
        ref_rst    = 0;
        repeat (5) @(posedge drifting_clk);
        
        // Wait for 100 reference ticks
        wait_ticks = 0;
        while (wait_ticks < 100) begin
            @(posedge ref_clk);
            if (ref_pulse) wait_ticks = wait_ticks + 1;
        end
        
        // Small delay to let last pulses propagate
        repeat (20) @(posedge drifting_clk);
        
        // Report results
        $display("  %3d°C  |  %+8.4f  |    %4d    |    %4d    |     %4d       |    %+4d ticks   |   %+4d ticks",
                 test_temp, drift_ppm,
                 ref_ticks, comp_ticks, uncomp_ticks,
                 comp_ticks - ref_ticks,
                 uncomp_ticks - ref_ticks);
    end

    // -------------------------------------------------------
    // SUMMARY
    // -------------------------------------------------------
    $display("");
    $display("================================================================");
    $display("  RESULTS INTERPRETATION");
    $display("================================================================");
    $display("");
    $display("  Reference ticks  = always 100 (perfect clock, the truth)");
    $display("  Comp ticks       = should be ~100 (LUT corrects the drift)");
    $display("  Uncomp ticks     = drifts away from 100 at high temperatures");
    $display("");
    $display("  Comp Error ≈ 0   → COMPENSATION WORKS! LUT cancels the drift.");
    $display("  Uncomp Error ≠ 0 → Without correction, the clock drifts.");
    $display("");
    $display("  The difference between Comp Error and Uncomp Error is the");
    $display("  drift that the LUT successfully corrected.");
    $display("================================================================");
    $display("");
    
    #100000;
    $finish;
end

endmodule
