`timescale 1ns / 1ps

module adc_system_top (

    // Zynq PS hard interfaces
    inout wire [14:0] DDR_addr,
    inout wire [2:0]  DDR_ba,
    inout wire DDR_cas_n,
    inout wire DDR_ck_n,
    inout wire DDR_ck_p,
    inout wire DDR_cke,
    inout wire DDR_cs_n,
    inout wire [3:0] DDR_dm,
    inout wire [31:0] DDR_dq,
    inout wire [3:0] DDR_dqs_n,
    inout wire [3:0] DDR_dqs_p,
    inout wire DDR_odt,
    inout wire DDR_ras_n,
    inout wire DDR_reset_n,
    inout wire DDR_we_n,

    inout wire FIXED_IO_ddr_vrn,
    inout wire FIXED_IO_ddr_vrp,
    inout wire [53:0] FIXED_IO_mio,
    inout wire FIXED_IO_ps_clk,
    inout wire FIXED_IO_ps_porb,
    inout wire FIXED_IO_ps_srstb,

    // Physical ADC interfaces
    input wire adc_clk0_p,
    input wire adc_clk0_n,
    input wire adc_clk1_p,
    input wire adc_clk1_n,

    input wire [3:0][6:0] adc_data_pins,

    // ADC SPI configuration interface
    output wire spi_csa_o,
    output wire spi_csb_o,
    output wire spi_clk_o,
    output wire spi_mosi_o
);

    wire ps_fclk_125;
    wire ps_resetn;
    wire spi_done;

    // Zynq Processing System
    adc_ps_startup_wrapper u_ps (

        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),

        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),

        .FCLK_CLK0(ps_fclk_125),
        .FCLK_RESET0_N(ps_resetn)
    );

    // SPI initialization + ADC acquisition + dual ILA
    adc_spi_ila_bridge u_adc_bridge (

        .ps_fclk_125(ps_fclk_125),
        .ps_resetn(ps_resetn),

        .adc_clk0_p(adc_clk0_p),
        .adc_clk0_n(adc_clk0_n),
        .adc_clk1_p(adc_clk1_p),
        .adc_clk1_n(adc_clk1_n),

        .adc_data_pins(adc_data_pins),

        .spi_csa_o(spi_csa_o),
        .spi_csb_o(spi_csb_o),
        .spi_clk_o(spi_clk_o),
        .spi_mosi_o(spi_mosi_o),

        .spi_done_o(spi_done)
    );

endmodule
