`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 04:29:47 PM
// Design Name: 
// Module Name: drift_demo_top
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
// drift_demo_top.v — Drift Compensation VISUAL DEMONSTRATION
//
// Board : Nexys A7-100T  |  Clock : 100 MHz
//
// WHY THE OLD DEMO DIDN'T WORK:
//   Both counters used the same drifting clock. Since they both count
//   cycles of the same oscillator, they both drift together. You can't
//   see a difference because there IS no reference.
//
// NEW APPROACH — SHOW THE CORRECTION ITSELF:
//   Instead of comparing two clocks, we SHOW the correction value 
//   accumulating over time. Every second, the LUT says "the crystal
//   drifted by N cycles." We add N to a running total.
//
//   At 25°C: delta = 0 cycles/sec  → accumulator stays at 0
//   At 40°C: delta = 788 cycles/sec → number grows by ~1 per second
//   At 70°C: delta = 7088 cycles/sec → number grows by ~7 per second
//   At 80°C: delta = 10588 cycles/sec → number grows by ~11 per second
//
//   Heat the board → watch the right counter speed up!
//   Cool it down → it slows back down!
//   THAT is the drift being corrected.
//
// DISPLAY (default):
//   AN[7:6] = Current temperature (°C)
//   AN[5:4] = blank
//   AN[3:0] = Total accumulated drift (÷1000, so readable numbers)
//             This counter speeds up as you heat the board!
//
// DISPLAY (press BTNU):
//   AN[7:4] = Current delta per second (from LUT) 
//   AN[3:0] = Total accumulated drift (÷1000)
//
// SWITCHES:
//   SW[0] = 0: Normal speed (update 1×/sec)
//   SW[0] = 1: Fast mode (update 10×/sec, drift grows 10× faster)
//
// BUTTONS:
//   BTNC = Reset drift accumulator to 0
//   BTNU = Toggle display mode
//////////////////////////////////////////////////////////////////////////////

module drift_demo_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire [1:0]  SW,
    
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,
    output wire [15:0] LED
);

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
wire btn_reset, btn_toggle;
button_debounce db_c (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNC), .btn_pulse(btn_reset));
button_debounce db_u (.clk(CLK100MHZ), .rst(rst), .btn_in(BTNU), .btn_pulse(btn_toggle));

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

// ============================================================
// Compute delta: how many cycles/sec the LUT corrects
// ============================================================
// NOMINAL (integer) = 100,000,000
// CORRECTED (integer) = active_corrected[35:8]
// DELTA = NOMINAL - CORRECTED (always positive, crystal runs slow)

wire [27:0] corrected_int = active_corrected[35:8];
wire [15:0] delta_per_tick;

// Careful subtraction (nominal >= corrected for negative drift)
assign delta_per_tick = (28'd100_000_000 >= corrected_int) ?
                        (28'd100_000_000 - corrected_int) : 16'd0;

// ============================================================
// Tick Generator (1 Hz or 10 Hz)
// ============================================================
reg [26:0] tick_counter;
reg        tick;
wire [26:0] tick_limit = SW[0] ? 27'd9_999_999 : 27'd99_999_999;

always @(posedge CLK100MHZ) begin
    if (rst || btn_reset) begin
        tick_counter <= 0;
        tick         <= 0;
    end else begin
        tick <= 0;
        if (tick_counter >= tick_limit) begin
            tick_counter <= 0;
            tick         <= 1;
        end else
            tick_counter <= tick_counter + 1;
    end
end

// ============================================================
// Drift Accumulator
// ============================================================
// Each tick, add delta_per_tick to running total.
// This represents the total cycles of drift that have been corrected.
// Divide by 1000 for display so numbers are readable.
//
// At 70°C: delta = 7088 per tick
//   After 1 second:  accumulator = 7088    → display = 7
//   After 10 seconds: accumulator = 70880  → display = 70
//   After 100 seconds: accumulator = 708800 → display = 708

reg [31:0] drift_accumulator;

always @(posedge CLK100MHZ) begin
    if (rst || btn_reset)
        drift_accumulator <= 0;
    else if (tick)
        drift_accumulator <= drift_accumulator + {16'd0, delta_per_tick};
end

// Display value = accumulator / 1000
wire [31:0] drift_divided = drift_accumulator / 1000;
wire [13:0] drift_for_display = (drift_divided > 9999) ? 14'd9999 : drift_divided[13:0];

// ============================================================
// Elapsed Seconds Counter (for reference)
// ============================================================
reg [15:0] elapsed;
always @(posedge CLK100MHZ) begin
    if (rst || btn_reset) elapsed <= 0;
    else if (tick) elapsed <= elapsed + 1;
end

// ============================================================
// Display Mode
// ============================================================
reg show_delta;  // 0 = temp + accumulated drift, 1 = delta/sec + accumulated drift

always @(posedge CLK100MHZ) begin
    if (rst) show_delta <= 0;
    else if (btn_toggle) show_delta <= ~show_delta;
end

// ============================================================
// 7-Segment Display
// ============================================================
reg [3:0] digit [0:7];
reg [7:0] dp_mask;

// Clamp delta_per_tick for display (max 9999)
wire [13:0] delta_display = (delta_per_tick > 9999) ? 14'd9999 : delta_per_tick[13:0];

always @(*) begin
    // Right 4 digits: always show accumulated drift ÷ 1000
    digit[3] = drift_for_display / 1000;
    digit[2] = (drift_for_display % 1000) / 100;
    digit[1] = (drift_for_display % 100) / 10;
    digit[0] = drift_for_display % 10;

    if (show_delta) begin
        // Left 4 digits: current delta per second (raw from LUT)
        digit[7] = delta_display / 1000;
        digit[6] = (delta_display % 1000) / 100;
        digit[5] = (delta_display % 100) / 10;
        digit[4] = delta_display % 10;
        dp_mask  = 8'b00010000;  // separator between delta and accumulated
    end else begin
        // Left 2 digits: temperature, middle blank
        digit[7] = current_temp / 10;
        digit[6] = current_temp % 10;
        digit[5] = 4'hF;  // blank
        digit[4] = 4'hF;  // blank
        dp_mask  = 8'b01000000;  // after temp
    end
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
    else if (tick) heartbeat <= ~heartbeat;
end

assign LED[7:0]   = current_temp;
assign LED[8]     = SW[0];                       // Speed mode
assign LED[9]     = show_delta;                  // Display mode
assign LED[12:10] = 3'b000;
assign LED[13]    = (delta_per_tick > 0);        // Drift present
assign LED[14]    = heartbeat;
assign LED[15]    = (drift_accumulator > 0);     // Drift accumulated

endmodule
