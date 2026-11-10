`timescale 1ns / 1ps

module adc_input_delay (
    input  wire             clk_ref_200,
    input  wire             idelay_rst,
    input  wire [3:0][6:0]  adc_data_pins,

    output wire [3:0][6:0]  adc_data_delayed,
    output wire             idelay_ready
);

    // 200 MHz REFCLK must be BUFG-buffered.
    // Assert reset for >= 50 ns after REFCLK is stable.

    (* IODELAY_GROUP = "adc_inputs" *)
    IDELAYCTRL idelay_ctrl (
        .REFCLK(clk_ref_200),
        .RST(idelay_rst),
        .RDY(idelay_ready)
    );

    genvar ch, bit_idx;

    generate
        for (ch = 0; ch < 4; ch = ch + 1) begin : g_channel
            for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin : g_bit

                (* IODELAY_GROUP = "adc_inputs" *)
                IDELAYE2 #(
                    .CINVCTRL_SEL("FALSE"),
                    .DELAY_SRC("IDATAIN"),
                    .HIGH_PERFORMANCE_MODE("TRUE"),
                    .IDELAY_TYPE("FIXED"),
                    .IDELAY_VALUE(4),
                    .PIPE_SEL("FALSE"),
                    .REFCLK_FREQUENCY(200.0),
                    .SIGNAL_PATTERN("DATA")
                ) idelay_adc (
                    .DATAOUT(adc_data_delayed[ch][bit_idx]),
                    .IDATAIN(adc_data_pins[ch][bit_idx]),
                    .DATAIN(1'b0),
                    .C(1'b0),
                    .CE(1'b0),
                    .INC(1'b0),
                    .LD(1'b0),
                    .LDPIPEEN(1'b0),
                    .REGRST(1'b0),
                    .CINVCTRL(1'b0),
                    .CNTVALUEIN(5'b00000),
                    .CNTVALUEOUT()
                );

            end
        end
    endgenerate

endmodule
