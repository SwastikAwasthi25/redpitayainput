`timescale 1ns / 1ps

module adc_frontend_top (

    input wire adc_clk0_p,
    input wire adc_clk0_n,

    input wire adc_clk1_p,
    input wire adc_clk1_n,

    input wire startup_resetn,

    input wire [3:0][6:0] adc_data_pins,

    output wire [3:0][13:0] adc_raw,
    output wire [3:0][13:0] adc_signed,

    output wire [1:0] adc_sample_clk,
    output wire clk_ref_200,

    output wire clk_01_locked,
    output wire clk_23_locked,

    output wire idelay_rst,
    output wire idelay_ready,
    output wire calibration_ready
);

    // Clock generation and IDELAY reset control
    adc_clock_top u_adc_clocks (
        .adc_clk0_p       (adc_clk0_p),
        .adc_clk0_n       (adc_clk0_n),
        .adc_clk1_p       (adc_clk1_p),
        .adc_clk1_n       (adc_clk1_n),

        .startup_resetn   (startup_resetn),
        .idelay_ready     (idelay_ready),

        .adc_sample_clk   (adc_sample_clk),
        .clk_ref_200      (clk_ref_200),

        .clk_01_locked    (clk_01_locked),
        .clk_23_locked    (clk_23_locked),

        .idelay_rst       (idelay_rst),
        .calibration_ready(calibration_ready)
    );

    // Physical ADC data capture
    adc_capture_core u_adc_capture (
        .adc_sample_clk  (adc_sample_clk),
        .clk_ref_200     (clk_ref_200),
        .idelay_rst      (idelay_rst),

        .adc_data_pins   (adc_data_pins),

        .adc_raw         (adc_raw),
        .adc_signed      (adc_signed),

        .idelay_ready    (idelay_ready)
    );

endmodule
