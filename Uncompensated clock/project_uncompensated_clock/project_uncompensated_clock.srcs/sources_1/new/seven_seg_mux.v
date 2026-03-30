`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 07:55:18 PM
// Design Name: 
// Module Name: seven_seg_mux
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
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2026 12:27:24 PM
// Design Name: 
// Module Name: seven_seg_mux
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
// seven_seg_mux.v — 8-digit multiplexed 7-segment display driver
//
// Board : Nexys A7-100T (8 common-anode 7-segment digits)
// Clock : 100 MHz
//
// How it works:
//   - Only one digit is lit at a time (multiplexed)
//   - A 17-bit counter selects which digit is active
//   - At 100 MHz: bits [16:14] cycle through 8 digits
//     → Each digit ON for 2^14 = 16,384 cycles = 163.84 µs
//     → Full scan of all 8 digits = 1.31 ms → ~763 Hz refresh
//     → No visible flicker (human eye threshold ~60 Hz)
//
// Nexys A7 7-segment hardware:
//   - Cathodes (segments a-g) are ACTIVE-LOW: 0 = segment ON
//   - Anodes (digit enables) are ACTIVE-LOW: 0 = digit ON
//   - Segment mapping: seg[6:0] = {g, f, e, d, c, b, a}
//
//       --- a ---
//      |         |
//      f         b
//      |         |
//       --- g ---
//      |         |
//      e         c
//      |         |
//       --- d ---   . dp
//
// Digit 4'hF = blank (all segments OFF)
//////////////////////////////////////////////////////////////////////////////

module seven_seg_mux (
    input  wire       clk,        // 100 MHz system clock
    input  wire       rst,        // Active-high synchronous reset
    input  wire [3:0] digit0,     // Rightmost digit (AN[0]) — 4-bit hex value
    input  wire [3:0] digit1,     // AN[1]
    input  wire [3:0] digit2,     // AN[2]
    input  wire [3:0] digit3,     // AN[3]
    input  wire [3:0] digit4,     // AN[4]
    input  wire [3:0] digit5,     // AN[5]
    input  wire [3:0] digit6,     // AN[6]
    input  wire [3:0] digit7,     // Leftmost digit (AN[7])
    input  wire [7:0] dp_in,      // Decimal point per digit (1 = ON)
    output reg  [6:0] seg,        // Cathode segments {g,f,e,d,c,b,a} (active-low)
    output reg        dp,         // Decimal point (active-low)
    output reg  [7:0] an          // Anode enables (active-low)
);

// ============================================================
// Refresh Counter
// ============================================================
// 17-bit free-running counter. Top 3 bits select the active digit.
// Frequency per digit = 100 MHz / 2^17 = ~763 Hz
// Full scan rate = 763 / 8 ≈ 95 Hz (no flicker)

reg [16:0] refresh_counter;
wire [2:0] digit_select = refresh_counter[16:14];

always @(posedge clk) begin
    if (rst)
        refresh_counter <= 17'd0;
    else
        refresh_counter <= refresh_counter + 1'b1;
end

// ============================================================
// Digit Multiplexer
// ============================================================
// Select which digit value and decimal point to display

reg [3:0] current_digit;
reg       current_dp;

always @(*) begin
    case (digit_select)
        3'd0: begin current_digit = digit0; current_dp = dp_in[0]; end
        3'd1: begin current_digit = digit1; current_dp = dp_in[1]; end
        3'd2: begin current_digit = digit2; current_dp = dp_in[2]; end
        3'd3: begin current_digit = digit3; current_dp = dp_in[3]; end
        3'd4: begin current_digit = digit4; current_dp = dp_in[4]; end
        3'd5: begin current_digit = digit5; current_dp = dp_in[5]; end
        3'd6: begin current_digit = digit6; current_dp = dp_in[6]; end
        3'd7: begin current_digit = digit7; current_dp = dp_in[7]; end
    endcase
end

// ============================================================
// Anode Driver (active-low: 0 = digit ON)
// ============================================================
// Enable exactly one anode at a time

always @(*) begin
    an = 8'b1111_1111;           // All digits OFF
    an[digit_select] = 1'b0;    // Turn ON the selected digit
end

// ============================================================
// 7-Segment Decoder (active-low: 0 = segment ON)
// ============================================================
// Decodes 4-bit hex value to 7 segments
// seg[6:0] = {g, f, e, d, c, b, a}
//
//  Hex    a b c d e f g    Binary (gfedcba)    Display
//  ---    -------------    ---------------     -------
//  0x0    1 1 1 1 1 1 0    100_0000             0
//  0x1    0 1 1 0 0 0 0    111_1001             1
//  0x2    1 1 0 1 1 0 1    010_0100             2
//  ...
//  0xF    all OFF          111_1111            (blank)

always @(*) begin
    case (current_digit)
        //                    gfe_dcba
        4'h0: seg = 7'b100_0000;  //  0
        4'h1: seg = 7'b111_1001;  //  1
        4'h2: seg = 7'b010_0100;  //  2
        4'h3: seg = 7'b011_0000;  //  3
        4'h4: seg = 7'b001_1001;  //  4
        4'h5: seg = 7'b001_0010;  //  5
        4'h6: seg = 7'b000_0010;  //  6
        4'h7: seg = 7'b111_1000;  //  7
        4'h8: seg = 7'b000_0000;  //  8
        4'h9: seg = 7'b001_0000;  //  9
        4'hA: seg = 7'b000_1000;  //  A
        4'hB: seg = 7'b000_0011;  //  b
        4'hC: seg = 7'b100_0110;  //  C
        4'hD: seg = 7'b010_0001;  //  d
        4'hE: seg = 7'b000_0110;  //  E
        4'hF: seg = 7'b111_1111;  //  (blank)
        default: seg = 7'b111_1111;
    endcase
    
    dp = ~current_dp;  // Invert: dp_in=1 means ON, but hardware is active-low
end

endmodule
