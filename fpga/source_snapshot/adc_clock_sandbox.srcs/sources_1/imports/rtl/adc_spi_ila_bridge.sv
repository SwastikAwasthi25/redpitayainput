`timescale 1ns / 1ps

module adc_spi_ila_bridge (
    input wire ps_fclk_125,
    input wire ps_resetn,

    input wire adc_clk0_p,
    input wire adc_clk0_n,
    input wire adc_clk1_p,
    input wire adc_clk1_n,

    input wire [3:0][6:0] adc_data_pins,

    output wire spi_csa_o,
    output wire spi_csb_o,
    output wire spi_clk_o,
    output wire spi_mosi_o,

    output wire spi_done_o
);

    wire spi_busy;

    adc_spi_init u_spi_init (
        .clk_125     (ps_fclk_125),
        .resetn      (ps_resetn),

        .spi_csa_o   (spi_csa_o),
        .spi_csb_o   (spi_csb_o),
        .spi_clk_o   (spi_clk_o),
        .spi_mosi_o  (spi_mosi_o),

        .spi_done_o  (spi_done_o),
        .spi_busy_o  (spi_busy)
    );

    // Release the clock generators only after
    // SPI initialization has completed.
    // Deassert reset synchronously to PS FCLK0.

    (* ASYNC_REG = "TRUE" *)
    logic [2:0] reset_release_sync;

    always_ff @(posedge ps_fclk_125 or negedge ps_resetn) begin
        if (!ps_resetn)
            reset_release_sync <= 3'b000;
        else if (!spi_done_o)
            reset_release_sync <= 3'b000;
        else
            reset_release_sync <= {
                reset_release_sync[1:0],
                1'b1
            };
    end

    wire adc_startup_resetn = reset_release_sync[2];

    // Existing ADC + dual ILA design.
    adc_ila_top u_adc_ila (
        .adc_clk0_p    (adc_clk0_p),
        .adc_clk0_n    (adc_clk0_n),
        .adc_clk1_p    (adc_clk1_p),
        .adc_clk1_n    (adc_clk1_n),

        .startup_resetn(adc_startup_resetn),
        .adc_data_pins (adc_data_pins)
    );

endmodule
