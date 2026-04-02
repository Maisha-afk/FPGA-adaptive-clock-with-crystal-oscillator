`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/02/2026 07:06:58 PM
// Design Name: 
// Module Name: seconds_generator
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

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// seconds_generator.v — Temperature-Compensated 1-Second Pulse Generator
//
// Board : Nexys A7-100T  |  Clock : 100 MHz
//
// PURPOSE:
//   Generates an accurate 1-second pulse by counting to the CORRECTED
//   terminal count from the drift LUT, instead of a fixed 100,000,000.
//
//   At 25°C: counts to 100,000,000.000 → exactly 1 second
//   At 70°C: counts to  99,992,912.500 → still exactly 1 second
//            (because the crystal runs slower, fewer cycles = 1 real second)
//
// FRACTIONAL ACCUMULATOR:
//   The corrected count has 8 fractional bits (UQ28.8 format).
//   Example: 99,992,912.500 → integer=99,992,912, fraction=0.5
//
//   If we only count to the integer part, we lose 0.5 cycles per second.
//   Over time this error accumulates: 0.5 cycles/sec × 86400 sec/day = 
//   43,200 cycles = 0.43 ms/day error.
//
//   The fractional accumulator fixes this:
//   - Each second, add the fractional part to a running accumulator
//   - When the accumulator overflows (>= 256 = 1.0), add 1 extra cycle
//     to that second's count
//   - This distributes the fractional error over multiple seconds
//
// INPUTS:
//   corrected_count [35:0] : UQ28.8 from drift LUT (updated on temp change)
//
// OUTPUTS:
//   one_sec_pulse : single-cycle pulse every corrected second
//////////////////////////////////////////////////////////////////////////////

module seconds_generator (
    input  wire        clk,             // 100 MHz
    input  wire        rst,             // Active-high synchronous reset
    input  wire [35:0] corrected_count, // UQ28.8 from drift LUT
    output reg         one_sec_pulse    // 1-cycle pulse every second
);

// Split corrected count into integer and fractional parts
wire [27:0] count_integer = corrected_count[35:8];   // ~100,000,000
wire [7:0]  count_frac    = corrected_count[7:0];    // 0.000 to 0.996

// ============================================================
// Fractional Accumulator
// ============================================================
// Accumulates the fractional part each second.
// When it overflows (>= 256), we add 1 to the terminal count.

reg [8:0] frac_accumulator;   // 9 bits to detect overflow (bit[8] = carry)
wire      frac_carry = frac_accumulator[8]; // 1 when accumulator >= 256

// ============================================================
// Terminal Count for This Second
// ============================================================
// Base terminal count = integer part of corrected_count
// If fractional accumulator overflowed, add 1 extra cycle

wire [27:0] terminal_count = frac_carry ? (count_integer + 1) : count_integer;

// ============================================================
// Main Cycle Counter
// ============================================================

reg [27:0] cycle_counter;

always @(posedge clk) begin
    if (rst) begin
        cycle_counter    <= 28'd0;
        frac_accumulator <= 9'd0;
        one_sec_pulse    <= 1'b0;
    end else begin
        one_sec_pulse <= 1'b0;
        
        if (cycle_counter >= terminal_count - 1) begin
            // === One second has elapsed ===
            cycle_counter <= 28'd0;
            one_sec_pulse <= 1'b1;
            
            // Accumulate fractional part for next second
            // Add current fraction, keep only lower 8 bits
            // Carry (bit[8]) will be used next second
            frac_accumulator <= {1'b0, frac_accumulator[7:0]} + {1'b0, count_frac};
        end else begin
            cycle_counter <= cycle_counter + 1;
        end
    end
end

endmodule

