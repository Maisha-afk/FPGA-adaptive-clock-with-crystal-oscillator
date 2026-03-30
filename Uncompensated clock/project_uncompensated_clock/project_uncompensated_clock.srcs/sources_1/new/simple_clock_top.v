`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 07:53:14 PM
// Design Name: 
// Module Name: simple_clock_top
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
// simple_clock_top.v — UNCOMPENSATED Clock with EXAGGERATED Drift
//
// Board : Nexys A7-100T  |  Clock : 100 MHz
//
// PURPOSE:
//   Shows what happens WITHOUT compensation. The crystal drift is
//   EXAGGERATED by 10,000× so you can visually see the clock speed up
//   when you heat the board with a hairdryer.
//
//   Real drift at 70°C:    -70.9 ppm → 0.38 sec/hour (invisible)
//   Exaggerated at 70°C: -709,000 ppm → seconds tick ~3.4× faster!
//
// HOW IT WORKS:
//   Normal clock: counts to 100,000,000 cycles per second (always)
//   This clock:   counts to 100,000,000 - (delta × EXAGGERATION)
//
//   At 25°C: delta = 0        → counts to 100,000,000 → normal speed
//   At 40°C: delta = 788      → counts to 92,120,000  → ~8% faster
//   At 55°C: delta = 3,150    → counts to 68,500,000  → ~31% faster  
//   At 70°C: delta = 7,088    → counts to 29,120,000  → ~3.4× faster!
//
// DISPLAY:
//   AN[7:6] = Hours     AN[3:2] = Seconds
//   AN[5:4] = Minutes   AN[1:0] = Temperature
//   Dots separate: HH.MM.SS.TT
//
// BUTTONS:
//   BTNU = Set mode (NORMAL → SET_HOURS → SET_MINUTES → NORMAL)
//   BTNR = Increment selected field
//
// WHAT TO OBSERVE:
//   1. At room temp: clock ticks at normal 1-second rate
//   2. Heat with hairdryer: seconds start ticking FASTER
//   3. More heat = faster ticking
//   4. Remove heat: clock returns to normal speed
//   This proves the crystal drifts with temperature!
//////////////////////////////////////////////////////////////////////////////

module simple_clock_top (
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
// EXAGGERATION FACTOR
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
// Drift LUT — get the correction delta
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

// Delta = NOMINAL - CORRECTED (integer parts)
wire [27:0] corrected_int = active_corrected[35:8];
wire [27:0] nominal_int   = 28'd100_000_000;
wire [15:0] delta_per_sec = (nominal_int >= corrected_int) ?
                            (nominal_int - corrected_int) : 16'd0;

// ============================================================
// EXAGGERATED Terminal Count
// ============================================================
// Multiply delta by EXAGGERATION, subtract from nominal
// Clamp to minimum 10,000,000 (max 10 Hz tick rate)
wire [31:0] exaggerated_delta = {16'd0, delta_per_sec} * EXAGGERATION;
wire [27:0] raw_terminal = (exaggerated_delta < nominal_int) ?
                           (nominal_int - exaggerated_delta[27:0]) : 28'd10_000_000;
wire [27:0] terminal_count = (raw_terminal < 28'd10_000_000) ? 
                             28'd10_000_000 : raw_terminal;

// ============================================================
// DRIFTING 1-Second Generator
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

