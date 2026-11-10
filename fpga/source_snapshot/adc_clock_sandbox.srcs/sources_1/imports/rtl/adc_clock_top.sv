`timescale 1ns / 1ps

// Experimental PuzzleFW-inspired capture clock topology.
// Trial ONLY. No claim of placed/routed legal clock distribution or correct DDR timing.
module adc_clock_top (
    input  wire adc_clk0_p,
    input  wire adc_clk0_n,
    input  wire adc_clk1_p,
    input  wire adc_clk1_n,
    input  wire startup_resetn,
    input  wire idelay_ready,
    output wire [1:0] adc_sample_clk,
    output wire clk_ref_200,
    output wire clk_01_locked,
    output wire clk_23_locked,
    output wire idelay_rst,
    output wire calibration_ready
);

    wire clock_reset = ~startup_resetn;
    wire adc_clk0_ibuf;
    wire adc_clk1_ibuf;
    wire unused_clk_01_125;
    wire unused_clk_23_125;

    // One differential input buffer per ADC clock pair.
    IBUFDS u_adc_clk0_ibuf (
        .I(adc_clk0_p), .IB(adc_clk0_n), .O(adc_clk0_ibuf)
    );
    IBUFDS u_adc_clk1_ibuf (
        .I(adc_clk1_p), .IB(adc_clk1_n), .O(adc_clk1_ibuf)
    );

    // Regional source-synchronous clocks for ADC sampling (no MMCM phase shift).
    BUFR #(.BUFR_DIVIDE("BYPASS"), .SIM_DEVICE("7SERIES")) u_adc_clk0_bufr (
        .I(adc_clk0_ibuf), .CE(1'b1), .CLR(1'b0), .O(adc_sample_clk[0])
    );
    BUFR #(.BUFR_DIVIDE("BYPASS"), .SIM_DEVICE("7SERIES")) u_adc_clk1_bufr (
        .I(adc_clk1_ibuf), .CE(1'b1), .CLR(1'b0), .O(adc_sample_clk[1])
    );

    // Clock Wizard 01 still generates 200 MHz for IDELAYCTRL calibration.
    // Both Clock Wizards must be configured with PRIM_SOURCE = No_buffer.
    adc_clk_wiz_01 u_clk_01 (
        .clk_out1 (unused_clk_01_125),
        .clk_out2 (clk_ref_200),
        .reset    (clock_reset),
        .locked   (clk_01_locked),
        .clk_in1  (adc_clk0_ibuf)
    );

    // Global branch for ADC chip 2 MMCM lock monitoring.
    // ADC sampling remains on the independent BUFR clock.
    wire adc_clk1_global;

    BUFG u_adc_clk1_global_bufg (
        .I(adc_clk1_ibuf),
        .O(adc_clk1_global)
    );
    // Wizard 23 remains to provide its local MMCM lock status.
    adc_clk_wiz_23 u_clk_23 (
        .clk_out1 (unused_clk_23_125),
        .reset    (clock_reset),
        .locked   (clk_23_locked),
        .clk_in1  (adc_clk1_global)
    );

    adc_idelay_reset_seq u_idelay_reset (
        .clk_ref_200       (clk_ref_200),
        .startup_resetn    (startup_resetn),
        .clk_ref_locked    (clk_01_locked),
        .idelay_ready      (idelay_ready),
        .idelay_rst        (idelay_rst),
        .calibration_ready (calibration_ready)
    );
endmodule