`timescale 1ns / 1ps

module adc_sample_format (
    input  logic [13:0] raw_ch1,
    input  logic [13:0] raw_ch2,
    input  logic [13:0] raw_ch3,
    input  logic [13:0] raw_ch4,

    output logic signed [13:0] signed_ch1,
    output logic signed [13:0] signed_ch2,
    output logic signed [13:0] signed_ch3,
    output logic signed [13:0] signed_ch4
);

    // Red Pitaya 4-ADC raw data conversion.
    // Preserve MSB and invert lower 13 bits.

    assign signed_ch1 = {raw_ch1[13], ~raw_ch1[12:0]};
    assign signed_ch2 = {raw_ch2[13], ~raw_ch2[12:0]};
    assign signed_ch3 = {raw_ch3[13], ~raw_ch3[12:0]};
    assign signed_ch4 = {raw_ch4[13], ~raw_ch4[12:0]};

endmodule

