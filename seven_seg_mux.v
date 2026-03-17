`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 12:58:21 PM
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

module seven_seg_mux (

    input  wire       clk,

    input  wire       rst,

    input  wire [3:0] digit0, digit1, digit2, digit3,

    input  wire [3:0] digit4, digit5, digit6, digit7,

    input  wire [7:0] dp_in,    // decimal point per digit (1=on)

    output reg  [6:0] seg,      // active-low cathodes

    output reg        dp,       // active-low decimal point

    output reg  [7:0] an        // active-low anodes

);
 
// Refresh counter: cycle through 8 digits

// At 100 MHz, 17-bit counter gives ~763 Hz per digit (~95 Hz full scan)

reg [16:0] refresh_counter;

wire [2:0] digit_select = refresh_counter[16:14];
 
always @(posedge clk) begin

    if (rst)

        refresh_counter <= 0;

    else

        refresh_counter <= refresh_counter + 1;

end
 
// Digit multiplexer

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
 
// Anode driver (active-low: 0 = ON)

always @(*) begin

    an = 8'b1111_1111;  // all off

    an[digit_select] = 1'b0;  // enable current digit

end
 
// 7-segment decoder (active-low: 0 = segment ON)

//   Segment mapping: seg[6:0] = {g, f, e, d, c, b, a}

always @(*) begin

    case (current_digit)

        4'h0: seg = 7'b100_0000;

        4'h1: seg = 7'b111_1001;

        4'h2: seg = 7'b010_0100;

        4'h3: seg = 7'b011_0000;

        4'h4: seg = 7'b001_1001;

        4'h5: seg = 7'b001_0010;

        4'h6: seg = 7'b000_0010;

        4'h7: seg = 7'b111_1000;

        4'h8: seg = 7'b000_0000;

        4'h9: seg = 7'b001_0000;

        4'hA: seg = 7'b000_1000;

        4'hB: seg = 7'b000_0011;

        4'hC: seg = 7'b100_0110;

        4'hD: seg = 7'b010_0001;

        4'hE: seg = 7'b000_0110;

        4'hF: seg = 7'b111_1111; // blank (all off)

    endcase

    dp = ~current_dp;  // active-low

end
 
endmodule
 