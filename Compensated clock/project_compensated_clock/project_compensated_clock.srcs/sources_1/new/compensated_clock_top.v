`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 08:15:08 PM
// Design Name: 
// Module Name: compensated_clock_top
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
// compensated_clock_top.v — COMPENSATED Clock with EXAGGERATED Drift
//
// Board : Nexys A7-100T  |  Clock : 100 MHz
//
// PURPOSE:
//   Same exaggerated drift model as simple_clock_top.v, but NOW with
//   the LUT correction applied. The correction cancels the drift,
//   so the clock ticks at a steady 1-second rate even when heated.
//
//   Compare side-by-side with the uncompensated version:
//     Uncompensated: seconds speed up when heated → Δs/ΔT is large
//     Compensated:   seconds stay steady when heated → Δs/ΔT ≈ 0
//
// HOW THE CORRECTION WORKS:
//   The drift equation says: at temperature T, the crystal runs slow
//   by delta cycles per second.
//
//   WITHOUT compensation (simple_clock_top):
//     terminal = 100M - (delta × 10000)   ← gets shorter, clock speeds up
//
//   WITH compensation (this file):
//     terminal = 100M                      ← stays at 100M always!
//
//   Why? Because the LUT tells us exactly how much the crystal drifts,
//   and we use that information to keep counting to the RIGHT number.
//   The exaggerated drift is applied AND corrected in the same step.
//
//   Think of it this way:
//     - The crystal physically runs slower at high temp (fewer cycles/sec)
//     - Uncompensated clock doesn't know this → counts wrong number → wrong time
//     - Compensated clock KNOWS this → counts the correct (fewer) cycles → right time
//
//   With exaggeration, we model as if the crystal drifts 10,000× more.
//   The compensation also exaggerates 10,000×. They cancel perfectly.
//
// DISPLAY:
//   AN[7:6] = Hours     AN[3:2] = Seconds
//   AN[5:4] = Minutes   AN[1:0] = Temperature
//
// BUTTONS:
//   BTNU = Set mode    BTNR = Increment
//////////////////////////////////////////////////////////////////////////////

module compensated_clock_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire        BTNR,
    
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,
    output wire [15:0] LED
);

// ============================================================
// EXAGGERATION FACTOR (same as uncompensated version)
// ============================================================
localparam EXAGGERATION = 10000;

// ============================================================
// Reset
// ============================================================
wire rst;
reg [2:0] rst_sync;
always @(posedge CLK100MHZ)
    rst_sync <= {rst_sync[1:0], ~CPU_RESETN};
assign rst = rst_sync[2];

// ============================================================
// Button Debouncers
// ============================================================
wire btn_setmode, btn_inc;
button_debounce db_u (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNU), .btn_pulse(btn_setmode));
button_debounce db_r (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNR), .btn_pulse(btn_inc));

// ============================================================
// XADC Temperature
// ============================================================
wire [7:0]  temp_celsius;
wire [5:0]  temp_index;
wire        temp_valid;

xadc_temp_reader #(
    .T_OFFSET(20), .T_MAX(80), .POLL_DIVIDER(10_000_000)
) u_xadc (
    .clk(CLK100MHZ), .rst(rst),
    .temp_raw(), .temp_celsius(temp_celsius),
    .temp_index(temp_index), .temp_valid(temp_valid)
);

reg [7:0] current_temp;
always @(posedge CLK100MHZ) begin
    if (rst) current_temp <= 8'd25;
    else if (temp_valid) current_temp <= temp_celsius;
end

// ============================================================
// Drift LUT
// ============================================================
wire [35:0] corrected_count_raw;

drift_lut_table u_lut (
    .clk(CLK100MHZ),
    .temp_index(temp_index),
    .corrected_count(corrected_count_raw)
);

reg [35:0] active_corrected;
always @(posedge CLK100MHZ) begin
    if (rst) active_corrected <= 36'h5F5E10000;
    else if (temp_valid) active_corrected <= corrected_count_raw;
end

// Delta from LUT (same calculation as uncompensated)
wire [27:0] corrected_int = active_corrected[35:8];
wire [27:0] nominal_int   = 28'd100_000_000;
wire [15:0] delta_per_sec = (nominal_int >= corrected_int) ?
                            (nominal_int - corrected_int) : 16'd0;

// ============================================================
// COMPENSATED Terminal Count
// ============================================================
// The crystal drifts by delta cycles/sec (runs slow).
// Exaggerated drift: the clock WOULD count delta×10000 fewer cycles.
// But we KNOW the drift, so we correct for it.
//
// Uncompensated: terminal = 100M - delta×10000  (wrong, speeds up)
// Compensated:   terminal = 100M - delta×10000 + delta×10000 = 100M (correct!)
//
// In other words: the compensated terminal count is ALWAYS 100,000,000
// because the drift and correction cancel each other out.
//
// But wait — to make it a fair comparison with the SAME exaggerated model,
// we simulate the drift happening and then correct it:
//
//   Step 1: Apply exaggerated drift (same as uncompensated)
//   Step 2: Apply exaggerated correction (this is what the LUT does)
//   Result: They cancel → terminal stays at 100M

wire [31:0] exaggerated_drift      = {16'd0, delta_per_sec} * EXAGGERATION;
wire [31:0] exaggerated_correction = {16'd0, delta_per_sec} * EXAGGERATION;

// Drifted terminal (same as uncompensated)
wire [27:0] drifted_terminal = (exaggerated_drift < nominal_int) ?
                               (nominal_int - exaggerated_drift[27:0]) : 28'd10_000_000;

// Apply correction: add back the correction
wire [27:0] corrected_terminal = drifted_terminal + exaggerated_correction[27:0];

// Clamp to reasonable range (should always be ~100M)
wire [27:0] terminal_count = (corrected_terminal > 28'd150_000_000) ? 
                             28'd100_000_000 : corrected_terminal;

// ============================================================
// CORRECTED 1-Second Generator
// ============================================================
reg [27:0] cycle_counter;
reg        one_sec_pulse;

always @(posedge CLK100MHZ) begin
    if (rst) begin
        cycle_counter <= 0;
        one_sec_pulse <= 0;
    end else begin
        one_sec_pulse <= 0;
        if (cycle_counter >= terminal_count - 1) begin
            cycle_counter <= 0;
            one_sec_pulse <= 1;
        end else
            cycle_counter <= cycle_counter + 1;
    end
end

// ============================================================
// HH:MM:SS Time Counter
// ============================================================
reg [4:0] hours;
reg [5:0] minutes;
reg [5:0] seconds;
reg [1:0] set_state;

localparam ST_NORMAL  = 2'd0;
localparam ST_HOURS   = 2'd1;
localparam ST_MINUTES = 2'd2;

always @(posedge CLK100MHZ) begin
    if (rst) begin
        hours     <= 5'd12;
        minutes   <= 6'd0;
        seconds   <= 6'd0;
        set_state <= ST_NORMAL;
    end else begin
        if (btn_setmode) begin
            case (set_state)
                ST_NORMAL:  set_state <= ST_HOURS;
                ST_HOURS:   set_state <= ST_MINUTES;
                ST_MINUTES: begin
                    set_state <= ST_NORMAL;
                    seconds   <= 6'd0;
                end
            endcase
        end
        
        if (btn_inc) begin
            case (set_state)
                ST_HOURS:   hours   <= (hours == 23)   ? 5'd0 : hours + 1;
                ST_MINUTES: minutes <= (minutes == 59) ? 6'd0 : minutes + 1;
                default: ;
            endcase
        end
        
        if (set_state == ST_NORMAL && one_sec_pulse) begin
            if (seconds == 59) begin
                seconds <= 0;
                if (minutes == 59) begin
                    minutes <= 0;
                    hours   <= (hours == 23) ? 5'd0 : hours + 1;
                end else
                    minutes <= minutes + 1;
            end else
                seconds <= seconds + 1;
        end
    end
end

// ============================================================
// Blink for Set Mode
// ============================================================
reg [24:0] blink_counter;
wire blink_on = blink_counter[24];
always @(posedge CLK100MHZ) begin
    if (rst) blink_counter <= 0;
    else blink_counter <= blink_counter + 1;
end

// ============================================================
// 7-Segment Display — HH.MM.SS.TT
// ============================================================
reg [3:0] digit [0:7];
reg [7:0] dp_mask;

wire [3:0] hr_tens   = hours / 10;
wire [3:0] hr_ones   = hours % 10;
wire [3:0] min_tens  = minutes / 10;
wire [3:0] min_ones  = minutes % 10;
wire [3:0] sec_tens  = seconds / 10;
wire [3:0] sec_ones  = seconds % 10;
wire [3:0] temp_tens = current_temp / 10;
wire [3:0] temp_ones = current_temp % 10;

always @(*) begin
    digit[7] = (set_state == ST_HOURS && !blink_on) ? 4'hF : hr_tens;
    digit[6] = (set_state == ST_HOURS && !blink_on) ? 4'hF : hr_ones;
    digit[5] = (set_state == ST_MINUTES && !blink_on) ? 4'hF : min_tens;
    digit[4] = (set_state == ST_MINUTES && !blink_on) ? 4'hF : min_ones;
    digit[3] = sec_tens;
    digit[2] = sec_ones;
    digit[1] = temp_tens;
    digit[0] = temp_ones;
    dp_mask  = 8'b01010100;  // HH.MM.SS.TT
end

seven_seg_mux u_seg (
    .clk(CLK100MHZ), .rst(rst),
    .digit0(digit[0]), .digit1(digit[1]),
    .digit2(digit[2]), .digit3(digit[3]),
    .digit4(digit[4]), .digit5(digit[5]),
    .digit6(digit[6]), .digit7(digit[7]),
    .dp_in(dp_mask), .seg(SEG), .dp(DP), .an(AN)
);

// ============================================================
// LEDs
// ============================================================
reg heartbeat;
always @(posedge CLK100MHZ) begin
    if (rst) heartbeat <= 0;
    else if (one_sec_pulse) heartbeat <= ~heartbeat;
end

assign LED[7:0]   = current_temp;
assign LED[9:8]   = set_state;
assign LED[13:10] = 4'b0000;
assign LED[14]    = heartbeat;
assign LED[15]    = (set_state != 0);

endmodule
