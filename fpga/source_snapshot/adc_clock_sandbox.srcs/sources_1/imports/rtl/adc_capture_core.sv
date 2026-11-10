`timescale 1ns / 1ps

module adc_capture_core (
    input  wire [1:0]        adc_sample_clk,
    input  wire              clk_ref_200,
    input  wire              idelay_rst,
    input  wire [3:0][6:0]   adc_data_pins,

    output wire [3:0][13:0]  adc_raw,
    output wire [3:0][13:0]  adc_signed,
    output wire              idelay_ready
);

    wire [3:0][6:0] adc_data_delayed;

    adc_input_delay u_delay (
        .clk_ref_200(clk_ref_200),
        .idelay_rst(idelay_rst),
        .adc_data_pins(adc_data_pins),
        .adc_data_delayed(adc_data_delayed),
        .idelay_ready(idelay_ready)
    );

    adc_ddr_unpack u_ddr (
        .adc_sample_clk(adc_sample_clk),
        .adc_data_delayed(adc_data_delayed),
        .adc_raw(adc_raw)
    );

    adc_sample_format u_format (
        .raw_ch1(adc_raw[0]),
        .raw_ch2(adc_raw[1]),
        .raw_ch3(adc_raw[2]),
        .raw_ch4(adc_raw[3]),

        .signed_ch1(adc_signed[0]),
        .signed_ch2(adc_signed[1]),
        .signed_ch3(adc_signed[2]),
        .signed_ch4(adc_signed[3])
    );

endmodule
