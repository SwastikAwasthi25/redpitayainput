`timescale 1ns / 1ps

module adc_ddr_unpack (
    input  wire [1:0]       adc_sample_clk,
    input  wire [3:0][6:0]  adc_data_delayed,
    output wire [3:0][13:0] adc_raw
);

    genvar ch, bit_idx;

    generate
        for (ch = 0; ch < 4; ch = ch + 1) begin : g_channel
            for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin : g_bit

                IDDR #(
                    .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                    .INIT_Q1(1'b0),
                    .INIT_Q2(1'b0),
                    .SRTYPE("SYNC")
                ) iddr_adc (
                    .Q1(adc_raw[ch][2*bit_idx]),
                    .Q2(adc_raw[ch][2*bit_idx+1]),
                    .C (adc_sample_clk[ch/2]),
                    .CE(1'b1),
                    .D (adc_data_delayed[ch][bit_idx]),
                    .R (1'b0),
                    .S (1'b0)
                );

            end
        end
    endgenerate

endmodule
