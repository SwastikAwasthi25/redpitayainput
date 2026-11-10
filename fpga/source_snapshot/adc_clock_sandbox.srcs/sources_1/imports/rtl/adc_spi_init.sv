`timescale 1ns / 1ps

module adc_spi_init #(
    parameter integer STARTUP_CYCLES = 12500000
)(
    input  wire clk_125,
    input  wire resetn,

    output wire spi_csa_o,
    output wire spi_csb_o,
    output wire spi_clk_o,
    output wire spi_mosi_o,

    output reg  spi_done_o,
    output wire spi_busy_o
);

    localparam [2:0]
        ST_DELAY     = 3'd0,
        ST_START     = 3'd1,
        ST_WAIT_BUSY = 3'd2,
        ST_WAIT_IDLE = 3'd3,
        ST_DONE      = 3'd4;

    reg [2:0]  state;
    reg [31:0] delay_count;
    reg [1:0]  command_index;

    reg [15:0] spi_address;
    reg [15:0] spi_data;

    wire spi_busy;
    wire spi_start;
    wire spi_mosi_unused;
    wire [0:0] spi_cs;

    // Both physical ADC chips share one chip-select.
    assign spi_csa_o = spi_cs[0];
    assign spi_csb_o = spi_cs[0];

    assign spi_busy_o = spi_busy;
    assign spi_start = (state == ST_START);

    // Original 4-ADC register configuration.
    always @(*) begin
        spi_address = 16'h0001;
        spi_data    = 16'h0000;

        case (command_index)
            2'd0: begin
                spi_address = 16'h0001;
                spi_data    = 16'h0000;
            end

            2'd1: begin
                spi_address = 16'h0002;
                spi_data    = 16'h000D;
            end

            2'd2: begin
                spi_address = 16'h0003;
                spi_data    = 16'h0002;
            end

            2'd3: begin
                spi_address = 16'h0004;
                spi_data    = 16'h0000;
            end
        endcase
    end

    // Initialization state machine.
    always @(posedge clk_125 or negedge resetn) begin
        if (!resetn) begin
            state         <= ST_DELAY;
            delay_count   <= 32'd0;
            command_index <= 2'd0;
            spi_done_o    <= 1'b0;
        end else begin
            case (state)

                ST_DELAY: begin
                    if (delay_count >= STARTUP_CYCLES - 1)
                        state <= ST_START;
                    else
                        delay_count <= delay_count + 1'b1;
                end

                ST_START: begin
                    // Start is asserted for one clock cycle.
                    state <= ST_WAIT_BUSY;
                end

                ST_WAIT_BUSY: begin
                    if (spi_busy)
                        state <= ST_WAIT_IDLE;
                end

                ST_WAIT_IDLE: begin
                    if (!spi_busy) begin
                        if (command_index == 2'd3)
                            state <= ST_DONE;
                        else begin
                            command_index <= command_index + 1'b1;
                            state <= ST_START;
                        end
                    end
                end

                ST_DONE: begin
                    spi_done_o <= 1'b1;
                end

                default: state <= ST_DELAY;

            endcase
        end
    end

    // Reuse original Red Pitaya SPI master.
    spi_master #(
        .RST_ACT_LVL(0),
        .NUM_OF_CS(1)
    ) u_spi_master (
        .clk_i             (clk_125),
        .rst_i             (resetn),

        .spi_cs_o          (spi_cs),
        .spi_clk_o         (spi_clk_o),
        .spi_miso_i        (1'b0),
        .spi_mosi_t        (spi_mosi_unused),
        .spi_mosi_o        (spi_mosi_o),

        .spi_start_i       (spi_start),
        .dat_wr_h_i        (spi_address),
        .dat_wr_l_i        (spi_data),
        .dat_rd_l_o        (),

        .cfg_rw_i          (1'b0),
        .cfg_cs_act_i      (1'b1),
        .cfg_h_lng_i       (5'd8),
        .cfg_l_lng_i       (5'd8),
        .cfg_clk_presc_i   (8'd10),
        .cfg_clk_wr_edg_i  (1'b1),
        .cfg_clk_rd_edg_i  (1'b1),
        .cfg_clk_idle_i    (1'b1),

        .sts_spi_busy_o    (spi_busy)
    );

endmodule
