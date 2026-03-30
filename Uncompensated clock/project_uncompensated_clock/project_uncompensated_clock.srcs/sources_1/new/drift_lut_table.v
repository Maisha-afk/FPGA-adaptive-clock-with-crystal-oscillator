`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 07:54:58 PM
// Design Name: 
// Module Name: drift_lut_table
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
// Create Date: 03/28/2026 01:09:31 PM
// Design Name: 
// Module Name: drift_lut_table
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
// drift_lut_table.v — VALIDATED Temperature-to-corrected-count LUT
//
// Board  : Nexys A7-100T  |  Clock : 100 MHz
// Model  : AT-cut, beta = -0.035 ppm/C^2, T0 = 25.0C
// Status : VALIDATED against real hardware measurements (38-70C)
// Format : UQ28.8 fixed-point
//////////////////////////////////////////////////////////////////////////////

module drift_lut_table (
    input  wire        clk,
    input  wire [5:0]  temp_index,
    output reg  [35:0] corrected_count
);

localparam [35:0] NOMINAL = 36'h5F5E10000;

always @(posedge clk) begin
    case (temp_index)
        6'd0: corrected_count <= 36'h5F5E0A880; // 20C -0.8750ppm
        6'd1: corrected_count <= 36'h5F5E0C800; // 21C -0.5600ppm
        6'd2: corrected_count <= 36'h5F5E0E080; // 22C -0.3150ppm
        6'd3: corrected_count <= 36'h5F5E0F200; // 23C -0.1400ppm
        6'd4: corrected_count <= 36'h5F5E0FC80; // 24C -0.0350ppm
        6'd5: corrected_count <= 36'h5F5E10000; // 25C -0.0000ppm
        6'd6: corrected_count <= 36'h5F5E0FC80; // 26C -0.0350ppm
        6'd7: corrected_count <= 36'h5F5E0F200; // 27C -0.1400ppm
        6'd8: corrected_count <= 36'h5F5E0E080; // 28C -0.3150ppm
        6'd9: corrected_count <= 36'h5F5E0C800; // 29C -0.5600ppm
        6'd10: corrected_count <= 36'h5F5E0A880; // 30C -0.8750ppm
        6'd11: corrected_count <= 36'h5F5E08200; // 31C -1.2600ppm
        6'd12: corrected_count <= 36'h5F5E05480; // 32C -1.7150ppm
        6'd13: corrected_count <= 36'h5F5E02000; // 33C -2.2400ppm
        6'd14: corrected_count <= 36'h5F5DFE480; // 34C -2.8350ppm
        6'd15: corrected_count <= 36'h5F5DFA200; // 35C -3.5000ppm
        6'd16: corrected_count <= 36'h5F5DF5880; // 36C -4.2350ppm
        6'd17: corrected_count <= 36'h5F5DF0800; // 37C -5.0400ppm
        6'd18: corrected_count <= 36'h5F5DEB080; // 38C -5.9150ppm
        6'd19: corrected_count <= 36'h5F5DE5200; // 39C -6.8600ppm
        6'd20: corrected_count <= 36'h5F5DDEC80; // 40C -7.8750ppm
        6'd21: corrected_count <= 36'h5F5DD8000; // 41C -8.9600ppm
        6'd22: corrected_count <= 36'h5F5DD0C80; // 42C -10.1150ppm
        6'd23: corrected_count <= 36'h5F5DC9200; // 43C -11.3400ppm
        6'd24: corrected_count <= 36'h5F5DC1080; // 44C -12.6350ppm
        6'd25: corrected_count <= 36'h5F5DB8800; // 45C -14.0000ppm
        6'd26: corrected_count <= 36'h5F5DAF880; // 46C -15.4350ppm
        6'd27: corrected_count <= 36'h5F5DA6200; // 47C -16.9400ppm
        6'd28: corrected_count <= 36'h5F5D9C480; // 48C -18.5150ppm
        6'd29: corrected_count <= 36'h5F5D92000; // 49C -20.1600ppm
        6'd30: corrected_count <= 36'h5F5D87480; // 50C -21.8750ppm
        6'd31: corrected_count <= 36'h5F5D7C200; // 51C -23.6600ppm
        6'd32: corrected_count <= 36'h5F5D70880; // 52C -25.5150ppm
        6'd33: corrected_count <= 36'h5F5D64800; // 53C -27.4400ppm
        6'd34: corrected_count <= 36'h5F5D58080; // 54C -29.4350ppm
        6'd35: corrected_count <= 36'h5F5D4B200; // 55C -31.5000ppm
        6'd36: corrected_count <= 36'h5F5D3DC80; // 56C -33.6350ppm
        6'd37: corrected_count <= 36'h5F5D30000; // 57C -35.8400ppm
        6'd38: corrected_count <= 36'h5F5D21C80; // 58C -38.1150ppm
        6'd39: corrected_count <= 36'h5F5D13200; // 59C -40.4600ppm
        6'd40: corrected_count <= 36'h5F5D04080; // 60C -42.8750ppm
        6'd41: corrected_count <= 36'h5F5CF4800; // 61C -45.3600ppm
        6'd42: corrected_count <= 36'h5F5CE4880; // 62C -47.9150ppm
        6'd43: corrected_count <= 36'h5F5CD4200; // 63C -50.5400ppm
        6'd44: corrected_count <= 36'h5F5CC3480; // 64C -53.2350ppm
        6'd45: corrected_count <= 36'h5F5CB2000; // 65C -56.0000ppm
        6'd46: corrected_count <= 36'h5F5CA0480; // 66C -58.8350ppm
        6'd47: corrected_count <= 36'h5F5C8E200; // 67C -61.7400ppm
        6'd48: corrected_count <= 36'h5F5C7B880; // 68C -64.7150ppm
        6'd49: corrected_count <= 36'h5F5C68800; // 69C -67.7600ppm
        6'd50: corrected_count <= 36'h5F5C55080; // 70C -70.8750ppm
        6'd51: corrected_count <= 36'h5F5C41200; // 71C -74.0600ppm
        6'd52: corrected_count <= 36'h5F5C2CC80; // 72C -77.3150ppm
        6'd53: corrected_count <= 36'h5F5C18000; // 73C -80.6400ppm
        6'd54: corrected_count <= 36'h5F5C02C80; // 74C -84.0350ppm
        6'd55: corrected_count <= 36'h5F5BED200; // 75C -87.5000ppm
        6'd56: corrected_count <= 36'h5F5BD7080; // 76C -91.0350ppm
        6'd57: corrected_count <= 36'h5F5BC0800; // 77C -94.6400ppm
        6'd58: corrected_count <= 36'h5F5BA9880; // 78C -98.3150ppm
        6'd59: corrected_count <= 36'h5F5B92200; // 79C -102.0600ppm
        6'd60: corrected_count <= 36'h5F5B7A480; // 80C -105.8750ppm
        default: corrected_count <= NOMINAL;
    endcase
end

endmodule

