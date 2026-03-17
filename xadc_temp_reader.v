`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 12:57:40 PM
// Design Name: 
// Module Name: xadc_temp_reader
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
// xadc_temp_reader.v — XADC Temperature Sensor Interface
//
// Board : Nexys A7-100T (Artix-7 XC7A100T)
// Clock : 100 MHz system clock
//
// Reads the on-die temperature sensor via XADC DRP port.
// Converts raw ADC code to integer Celsius.
// Outputs a 6-bit LUT index = (temp_celsius - T_OFFSET) for the drift LUT.
//
// XADC temperature formula (Xilinx UG480):
//   T(°C) = (ADC_code * 503.975 / 4096) - 273.15
//
// Simplified fixed-point version (multiply then shift):
//   temp_raw = ADC_code * 504  (close enough to 503.975)
//   temp_celsius = (temp_raw >> 12) - 273
//////////////////////////////////////////////////////////////////////////////

module xadc_temp_reader #(
    parameter T_OFFSET     = 20,    // LUT starts at 20°C
    parameter T_MAX        = 80,    // LUT ends at 80°C
    parameter POLL_DIVIDER = 10_000_000  // Read every 100ms at 100MHz
) (
    input  wire        clk,          // 100 MHz system clock
    input  wire        rst,          // Active-high synchronous reset
    output reg  [11:0] temp_raw,     // Raw 12-bit XADC code (for debug)
    output reg  [7:0]  temp_celsius, // Temperature in °C (unsigned, 0-255)
    output reg  [5:0]  temp_index,   // LUT index = temp_celsius - T_OFFSET
    output reg         temp_valid    // Pulses high for 1 cycle on new reading
);

// ============================================================
// XADC Instantiation
// ============================================================

wire [15:0] xadc_dout;        // DRP read data
wire        xadc_drdy;        // DRP data ready
wire        xadc_eoc;         // End of conversion
wire        xadc_busy;        // XADC busy
wire [4:0]  xadc_channel;     // Current channel
wire        xadc_eos;         // End of sequence

reg  [6:0]  xadc_daddr;       // DRP address
reg         xadc_den;         // DRP enable (read strobe)
reg         xadc_dwe;         // DRP write enable
reg  [15:0] xadc_di;          // DRP write data

// XADC primitive — configured for on-chip temperature only
// The temperature is always available at status register 0x00
XADC #(
    .INIT_40(16'h1000),  // Config reg 0: averaging=off, single channel
    .INIT_41(16'h31AF),  // Config reg 1: continuous mode, enable calibration
    .INIT_42(16'h0400),  // Config reg 2: DCLK divider = 4 (25 MHz ADCCLK)
    .INIT_48(16'h0100),  // Sequence: enable temperature channel
    .INIT_49(16'h0000),  // Sequence: no aux channels
    .INIT_4A(16'h0000),  // Averaging: none
    .INIT_4B(16'h0000),
    .INIT_4C(16'h0000),
    .INIT_4D(16'h0000),
    .INIT_4E(16'h0000),
    .INIT_4F(16'h0000),
    .INIT_50(16'hB5ED),  // Temp upper alarm: 85°C
    .INIT_54(16'hA93A),  // Temp lower alarm: 60°C
    .SIM_MONITOR_FILE(""),
    .SIM_DEVICE("7SERIES")
) xadc_inst (
    // DRP interface
    .DCLK(clk),
    .DEN(xadc_den),
    .DADDR(xadc_daddr),
    .DWE(xadc_dwe),
    .DI(xadc_di),
    .DO(xadc_dout),
    .DRDY(xadc_drdy),
    // Status
    .BUSY(xadc_busy),
    .CHANNEL(xadc_channel),
    .EOC(xadc_eoc),
    .EOS(xadc_eos),
    // Unused inputs - tie off
    .CONVST(1'b0),
    .CONVSTCLK(1'b0),
    .RESET(rst),
    .VP(1'b0),
    .VN(1'b0),
    .VAUXP(16'b0),
    .VAUXN(16'b0),
    // Unused outputs
    .ALM(),
    .OT(),
    .MUXADDR(),
    .JTAGBUSY(),
    .JTAGLOCKED(),
    .JTAGMODIFIED()
);

// ============================================================
// Polling Timer — triggers a DRP read every POLL_DIVIDER cycles
// ============================================================

reg [23:0] poll_counter;
reg        poll_trigger;

always @(posedge clk) begin
    if (rst) begin
        poll_counter <= 0;
        poll_trigger <= 0;
    end else begin
        poll_trigger <= 0;
        if (poll_counter >= POLL_DIVIDER - 1) begin
            poll_counter <= 0;
            poll_trigger <= 1;
        end else begin
            poll_counter <= poll_counter + 1;
        end
    end
end

// ============================================================
// DRP Read FSM
// ============================================================

localparam S_IDLE    = 2'd0;
localparam S_READ    = 2'd1;
localparam S_WAIT    = 2'd2;
localparam S_CONVERT = 2'd3;

reg [1:0] state;
reg [15:0] adc_raw_reg;

always @(posedge clk) begin
    if (rst) begin
        state       <= S_IDLE;
        xadc_den    <= 0;
        xadc_dwe    <= 0;
        xadc_daddr  <= 7'h00;
        xadc_di     <= 16'h0000;
        adc_raw_reg <= 0;
        temp_raw    <= 0;
        temp_celsius <= 0;
        temp_index  <= 0;
        temp_valid  <= 0;
    end else begin
        xadc_den   <= 0;
        temp_valid <= 0;

        case (state)
            S_IDLE: begin
                if (poll_trigger && !xadc_busy) begin
                    // Initiate DRP read of temperature register (addr 0x00)
                    xadc_daddr <= 7'h00;
                    xadc_den   <= 1;
                    xadc_dwe   <= 0;
                    state      <= S_WAIT;
                end
            end

            S_WAIT: begin
                // Wait for DRDY
                if (xadc_drdy) begin
                    // XADC data format: bits [15:4] = 12-bit ADC code
                    adc_raw_reg <= xadc_dout;
                    state       <= S_CONVERT;
                end
            end

            S_CONVERT: begin
                // Convert raw ADC to temperature
                // ADC code is in bits [15:4] of the read data
                convert_temperature(adc_raw_reg[15:4]);
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

// ============================================================
// Temperature Conversion (combinational, used by FSM)
// ============================================================
// T(°C) = (code * 503.975 / 4096) - 273.15
// Simplified: T = (code * 504 >> 12) - 273
//
// We use a 2-stage approach:
//   Stage 1: multiply = code * 504  (needs 12+10 = 22 bits)
//   Stage 2: shift and subtract

reg [21:0] temp_product;
reg [8:0]  temp_shifted;   // 9-bit signed intermediate
reg [7:0]  temp_clamped;
reg [5:0]  index_clamped;

task convert_temperature;
    input [11:0] adc_code;
    begin
        // code * 504 (504 = 0x1F8)
        temp_product = adc_code * 504;
        
        // >> 12 gives integer Celsius + 273
        temp_shifted = temp_product[20:12]; // effectively divide by 4096
        
        // Subtract 273 to get Celsius
        if (temp_shifted > 273)
            temp_clamped = temp_shifted - 273;
        else
            temp_clamped = 0;
        
        // Clamp to LUT range and compute index
        if (temp_clamped < T_OFFSET)
            index_clamped = 0;
        else if (temp_clamped > T_MAX)
            index_clamped = T_MAX - T_OFFSET;
        else
            index_clamped = temp_clamped - T_OFFSET;
        
        // Register outputs
        temp_raw     <= adc_code;
        temp_celsius <= temp_clamped;
        temp_index   <= index_clamped;
        temp_valid   <= 1;
    end
endtask

endmodule