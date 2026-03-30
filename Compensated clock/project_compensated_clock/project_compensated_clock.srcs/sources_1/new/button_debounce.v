`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 08:15:56 PM
// Design Name: 
// Module Name: button_debounce
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
// button_debounce.v — Debouncer with Rising Edge Detection
//
// Filters mechanical switch bounce and outputs a single-cycle pulse
// on the rising edge of a stable button press.
// Default debounce window: 20 ms
//////////////////////////////////////////////////////////////////////////////

module button_debounce #(
    parameter CLK_FREQ    = 100_000_000,
    parameter DEBOUNCE_MS = 20
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,       // Raw button input (active-high)
    output reg  btn_pulse     // Single-cycle pulse on press
);

localparam DEBOUNCE_COUNT = (CLK_FREQ / 1000) * DEBOUNCE_MS;
localparam CNT_WIDTH = $clog2(DEBOUNCE_COUNT + 1);

reg [CNT_WIDTH-1:0] counter;
reg btn_stable, btn_prev;

always @(posedge clk) begin
    if (rst) begin
        counter    <= 0;
        btn_stable <= 0;
        btn_prev   <= 0;
        btn_pulse  <= 0;
    end else begin
        btn_pulse <= 0;

        // Count how long the input has been different from stable
        if (btn_in != btn_stable) begin
            if (counter == DEBOUNCE_COUNT - 1) begin
                counter    <= 0;
                btn_stable <= btn_in;
            end else
                counter <= counter + 1;
        end else
            counter <= 0;

        // Rising edge detection on debounced signal
        btn_prev <= btn_stable;
        if (btn_stable && !btn_prev)
            btn_pulse <= 1;
    end
end

endmodule
