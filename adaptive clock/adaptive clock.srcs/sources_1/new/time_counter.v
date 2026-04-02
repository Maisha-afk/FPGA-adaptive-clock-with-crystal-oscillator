`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/02/2026 07:06:00 PM
// Design Name: 
// Module Name: time_counter
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
// time_counter.v — HH:MM:SS Clock with Time Setting
//
// Counts hours:minutes:seconds driven by one_sec_pulse.
// Supports time setting via buttons (set_mode cycles through fields,
// set_inc increments the selected field).
//
// Set Mode FSM:
//   NORMAL → press set_mode → SET_HOURS → press set_mode → SET_MINUTES
//   → press set_mode → back to NORMAL
//   While in a SET state, the clock is PAUSED and set_inc increments
//   the selected field.
//////////////////////////////////////////////////////////////////////////////

module time_counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       one_sec_pulse,   // From seconds_generator
    input  wire       set_mode,        // Pulse: cycle through set states
    input  wire       set_inc,         // Pulse: increment selected field
    output reg [4:0]  hours,           // 0–23
    output reg [5:0]  minutes,         // 0–59
    output reg [5:0]  seconds,         // 0–59
    output reg [1:0]  set_state        // 0=NORMAL, 1=SET_HOURS, 2=SET_MINUTES
);

localparam ST_NORMAL  = 2'd0;
localparam ST_HOURS   = 2'd1;
localparam ST_MINUTES = 2'd2;

always @(posedge clk) begin
    if (rst) begin
        hours     <= 5'd12;  // Start at 12:00:00
        minutes   <= 6'd0;
        seconds   <= 6'd0;
        set_state <= ST_NORMAL;
    end else begin
        
        // --- Set Mode FSM ---
        if (set_mode) begin
            case (set_state)
                ST_NORMAL:  set_state <= ST_HOURS;
                ST_HOURS:   set_state <= ST_MINUTES;
                ST_MINUTES: begin
                    set_state <= ST_NORMAL;
                    seconds   <= 6'd0;  // Reset seconds when exiting set mode
                end
            endcase
        end
        
        // --- Increment selected field ---
        if (set_inc) begin
            case (set_state)
                ST_HOURS: begin
                    if (hours == 23)
                        hours <= 0;
                    else
                        hours <= hours + 1;
                end
                ST_MINUTES: begin
                    if (minutes == 59)
                        minutes <= 0;
                    else
                        minutes <= minutes + 1;
                end
                default: ; // No action in NORMAL mode
            endcase
        end
        
        // --- Normal counting (only when not in set mode) ---
        if (set_state == ST_NORMAL && one_sec_pulse) begin
            if (seconds == 59) begin
                seconds <= 0;
                if (minutes == 59) begin
                    minutes <= 0;
                    if (hours == 23)
                        hours <= 0;
                    else
                        hours <= hours + 1;
                end else begin
                    minutes <= minutes + 1;
                end
            end else begin
                seconds <= seconds + 1;
            end
        end
        
    end
end

endmodule

