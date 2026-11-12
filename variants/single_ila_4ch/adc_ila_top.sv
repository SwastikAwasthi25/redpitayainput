`timescale 1ns / 1ps

module adc_ila_top (
    input wire adc_clk0_p,
    input wire adc_clk0_n,
    input wire adc_clk1_p,
    input wire adc_clk1_n,
    input wire startup_resetn,
    input wire [3:0][6:0] adc_data_pins
);

    wire [3:0][13:0] adc_raw;
    wire [3:0][13:0] adc_signed;

    wire [1:0] adc_sample_clk;
    wire clk_ref_200;

    wire clk_01_locked;
    wire clk_23_locked;
    wire idelay_rst;
    wire idelay_ready;
    wire calibration_ready;

    adc_frontend_top u_frontend (
        .adc_clk0_p(adc_clk0_p),
        .adc_clk0_n(adc_clk0_n),
        .adc_clk1_p(adc_clk1_p),
        .adc_clk1_n(adc_clk1_n),
        .startup_resetn(startup_resetn),
        .adc_data_pins(adc_data_pins),
        .adc_raw(adc_raw),
        .adc_signed(adc_signed),
        .adc_sample_clk(adc_sample_clk),
        .clk_ref_200(clk_ref_200),
        .clk_01_locked(clk_01_locked),
        .clk_23_locked(clk_23_locked),
        .idelay_rst(idelay_rst),
        .idelay_ready(idelay_ready),
        .calibration_ready(calibration_ready)
    );


    // Local reset synchronization for each ADC clock domain.
    // Asynchronous assertion, synchronous deassertion.
    // Clock Wizard resets are already driven by ~startup_resetn upstream.
    // LOCKED is the direct asynchronous reset assertion for each local
    // sampling-clock domain; deassertion is synchronized by the pipe.
    // This avoids a combinational AND gate driving async CLR pins.
    wire reset12_request_n = clk_01_locked;
    wire reset34_request_n = clk_23_locked;

    (* ASYNC_REG = "TRUE" *) logic [2:0] reset12_pipe;
    (* ASYNC_REG = "TRUE" *) logic [2:0] reset34_pipe;

    always_ff @(posedge adc_sample_clk[0]
                or negedge reset12_request_n) begin
        if (!reset12_request_n)
            reset12_pipe <= 3'b000;
        else
            reset12_pipe <= {reset12_pipe[1:0], 1'b1};
    end

    always_ff @(posedge adc_sample_clk[1]
                or negedge reset34_request_n) begin
        if (!reset34_request_n)
            reset34_pipe <= 3'b000;
        else
            reset34_pipe <= {reset34_pipe[1:0], 1'b1};
    end

    wire reset12_n = reset12_pipe[2];
    wire reset34_n = reset34_pipe[2];

    // Status bit map:
    // [0] Clock Wizard 01 locked
    // [1] Clock Wizard 23 locked
    // [2] IDELAYCTRL ready
    // [3] Calibration ready

    wire [3:0] status_async = {
        calibration_ready,
        idelay_ready,
        clk_23_locked,
        clk_01_locked
    };

    // Synchronize status into CH1/CH2 clock domain.
    (* ASYNC_REG = "TRUE" *)
    logic [3:0] status12_meta, status12_sync;

    always_ff @(posedge adc_sample_clk[0] or negedge reset12_n) begin
        if (!reset12_n) begin
            status12_meta <= 4'b0;
            status12_sync <= 4'b0;
        end else begin
            status12_meta <= status_async;
            status12_sync <= status12_meta;
        end
    end

    // Synchronize status into CH3/CH4 clock domain.
    (* ASYNC_REG = "TRUE" *)
    logic [3:0] status34_meta, status34_sync;

    always_ff @(posedge adc_sample_clk[1] or negedge reset34_n) begin
        if (!reset34_n) begin
            status34_meta <= 4'b0;
            status34_sync <= 4'b0;
        end else begin
            status34_meta <= status_async;
            status34_sync <= status34_meta;
        end
    end

    // Independent sample-clock counters.
    logic [15:0] counter12;
    logic [15:0] counter34;

    always_ff @(posedge adc_sample_clk[0] or negedge reset12_n) begin
        if (!reset12_n)
            counter12 <= 16'd0;
        else if (!status12_sync[0] ||
                 !status12_sync[3])
            counter12 <= 16'd0;
        else
            counter12 <= counter12 + 16'd1;
    end

    always_ff @(posedge adc_sample_clk[1] or negedge reset34_n) begin
        if (!reset34_n)
            counter34 <= 16'd0;
        else if (!status34_sync[1] ||
                 !status34_sync[3])
            counter34 <= 16'd0;
        else
            counter34 <= counter34 + 16'd1;
    end

    // Experimental single-ILA debug variant.
    // LTC2145 A4=0x00 => offset-binary D13:D0; toggle bit 13 to
    // express the same code in 14-bit two's-complement format.
    // This is deliberately NOT the historical adc_signed = raw ^ 14'h1FFF.
    wire [13:0] adc_twos_ch0 = adc_raw[0] ^ 14'h2000;
    wire [13:0] adc_twos_ch1 = adc_raw[1] ^ 14'h2000;

    // EXPERIMENTAL phase compensation based on observed ~7.7-7.9 sample
    // lag of the FIFO-fed CH2/CH3 pair, measured at 1 and 5 MHz.
    // Delay CH0/CH1 by exactly 8 clock-0 cycles in the ILA presentation.
    // This neither changes the ADC captures nor fixes CDC clock phase.
    localparam integer DIRECT_PHASE_DELAY = 8;
    logic [13:0] ch0_delay_pipe [0:DIRECT_PHASE_DELAY-1];
    logic [13:0] ch1_delay_pipe [0:DIRECT_PHASE_DELAY-1];
    integer delay_idx;
    always_ff @(posedge adc_sample_clk[0]) begin
        ch0_delay_pipe[0] <= adc_twos_ch0;
        ch1_delay_pipe[0] <= adc_twos_ch1;
        for (delay_idx = 1; delay_idx < DIRECT_PHASE_DELAY;
             delay_idx = delay_idx + 1) begin
            ch0_delay_pipe[delay_idx] <= ch0_delay_pipe[delay_idx-1];
            ch1_delay_pipe[delay_idx] <= ch1_delay_pipe[delay_idx-1];
        end
    end
    wire [13:0] adc_twos_ch0_delayed =
        ch0_delay_pipe[DIRECT_PHASE_DELAY-1];
    wire [13:0] adc_twos_ch1_delayed =
        ch1_delay_pipe[DIRECT_PHASE_DELAY-1];

    // Qualify probe5[0] only after the 8-cycle pipeline contains
    // post-calibration samples; no extra CDC paths are introduced.
    logic [DIRECT_PHASE_DELAY-1:0] ch01_delay_valid = '0;
    always_ff @(posedge adc_sample_clk[0]) begin
        if (!reset12_n)
            ch01_delay_valid <= '0;
        else
            ch01_delay_valid <= {ch01_delay_valid[DIRECT_PHASE_DELAY-2:0],
                                 status12_sync[3]};
    end
    wire ch01_aligned_valid = ch01_delay_valid[DIRECT_PHASE_DELAY-1];

    // Both channels from ADC pair 2 share clk34 and must cross together.
    // Packing them into one FIFO word preserves their mutual sample pairing.
    wire [27:0] fifo_din = {
        (adc_raw[3] ^ 14'h2000),
        (adc_raw[2] ^ 14'h2000)
    };

    wire [27:0] fifo_dout;
    wire cdc_full, cdc_empty;
    wire cdc_wr_rst_busy, cdc_rd_rst_busy;

    // All signals below are native to sample-clock domain 1 (CH2/CH3).
    // XPM_FIFO_ASYNC requires reset release to be synchronous to wr_clk;
    // the source status is generated by registers clocked on that domain.
    // Register the readiness reduction before crossing the clock boundary.
    // A combinational AND feeding cdc_ready_sync was CDC-10 (critical).
    logic cdc_source_ready;
    always_ff @(posedge adc_sample_clk[1] or negedge reset34_n) begin
        if (!reset34_n)
            cdc_source_ready <= 1'b0;
        else
            cdc_source_ready <= status34_sync[0] &&
                                status34_sync[1] &&
                                status34_sync[3];
    end

    // AMD XPM_FIFO_ASYNC requires 'rst' synchronous to its write clock.
    // Initialize asserted for configuration/startup, then update only on
    // wr_clk rising edges (including following a local clock restart).
    logic cdc_fifo_rst = 1'b1;
    always_ff @(posedge adc_sample_clk[1]) begin
        cdc_fifo_rst <= !cdc_source_ready;
    end
    // RAMB36E1 control pins must not be directly driven by flops with
    // asynchronous resets. Qualify the FIFO enables using local-clocked
    // registers that have no asynchronous set/reset (REQP-1839).
    //
    // Explicit initialization is synthesizable for the target 7-series FPGA.
    // Reset/startup conditions are sampled on the respective ADC clock.
    logic cdc_wr_armed = 1'b0;
    always_ff @(posedge adc_sample_clk[1]) begin
        cdc_wr_armed <= cdc_source_ready && !cdc_fifo_rst &&
                        !cdc_wr_rst_busy;
    end
    wire cdc_wr_en = cdc_wr_armed && !cdc_full && !cdc_wr_rst_busy;

    // Consumer domain is CH0/CH1's sample clock (sample-clock domain 0).
    logic cdc_rd_armed = 1'b0;
    always_ff @(posedge adc_sample_clk[0]) begin
        cdc_rd_armed <= reset12_n && !cdc_rd_rst_busy;
    end
    wire cdc_valid = cdc_rd_armed && !cdc_empty && !cdc_rd_rst_busy;
    wire cdc_rd_en = cdc_valid;

    // Count or flag *lost samples* when the source cannot enqueue one
    // full-rate CH2/CH3 sample pair; do NOT silently claim coherent capture.
    logic cdc_drop_sticky_src;
    always_ff @(posedge adc_sample_clk[1] or negedge reset34_n) begin
        if (!reset34_n)
            cdc_drop_sticky_src <= 1'b0;
        else if (cdc_source_ready && !cdc_wr_rst_busy && cdc_full)
            cdc_drop_sticky_src <= 1'b1;
    end

    // Two-stage synchronizers for source-domain status-only flags.
    // Sample DATA is transferred only through the async FIFO.
    (* ASYNC_REG = "TRUE" *) logic [1:0] cdc_drop_sync;
    (* ASYNC_REG = "TRUE" *) logic [1:0] cdc_ready_sync;
    always_ff @(posedge adc_sample_clk[0] or negedge reset12_n) begin
        if (!reset12_n) begin
            cdc_drop_sync  <= 2'b00;
            cdc_ready_sync <= 2'b00;
        end else begin
            cdc_drop_sync  <= {cdc_drop_sync[0], cdc_drop_sticky_src};
            cdc_ready_sync <= {cdc_ready_sync[0], cdc_source_ready};
        end
    end

    // 28-bit x 2048-word asynchronous FIFO. Clocks are independently
    // forwarded by the two ADC chips. FWFT exposes the next pair whenever
    // cdc_valid=1; no bus bits are synchronized independently.
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .ECC_MODE("no_ecc"),
        .RELATED_CLOCKS(0),
        .FIFO_WRITE_DEPTH(2048),
        .WRITE_DATA_WIDTH(28),
        .WR_DATA_COUNT_WIDTH(12),
        .PROG_FULL_THRESH(2000),
        .FULL_RESET_VALUE(0),
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .READ_DATA_WIDTH(28),
        .RD_DATA_COUNT_WIDTH(12),
        .PROG_EMPTY_THRESH(8),
        .DOUT_RESET_VALUE("0"),
        .CDC_SYNC_STAGES(2),
        .WAKEUP_TIME(0),
        .USE_ADV_FEATURES("0707"),
        .SIM_ASSERT_CHK(1)
    ) u_adc34_cdc_fifo (
        .rst(cdc_fifo_rst),
        .wr_clk(adc_sample_clk[1]),
        .wr_en(cdc_wr_en),
        .din(fifo_din),
        .full(cdc_full),
        .wr_rst_busy(cdc_wr_rst_busy),
        .rd_clk(adc_sample_clk[0]),
        .rd_en(cdc_rd_en),
        .dout(fifo_dout),
        .empty(cdc_empty),
        .rd_rst_busy(cdc_rd_rst_busy),
        .sleep(1'b0),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .almost_empty(),
        .almost_full(),
        .data_valid(),
        .dbiterr(),
        .overflow(),
        .prog_empty(),
        .prog_full(),
        .rd_data_count(),
        .sbiterr(),
        .underflow(),
        .wr_ack(),
        .wr_data_count()
    );

    wire [13:0] adc_twos_ch2 = fifo_dout[13:0];
    wire [13:0] adc_twos_ch3 = fifo_dout[27:14];

    // Reuse the already-exported 6-probe/4096-depth adc_ila_12 IP.
    // Only ONE ILA is instantiated in this variant, clocked by CH0/CH1.
    //
    // probe0: CH0 two's complement delayed 8 ADC0 cycles
    // probe1: CH1 two's complement delayed 8 ADC0 cycles
    // probe2: signed 14-bit CH2 via async FIFO; trust only if probe5[2]
    // probe3: signed 14-bit CH3 via async FIFO; trust only if probe5[2]
    // probe4: 16-bit CH0/CH1 sample counter
    // probe5: [3] FIFO drop observed in source (sticky, synchronized)
    //         [2] FIFO data valid at probe2/probe3
    //         [1] CH2/CH3 source readiness (synchronized)
    //         [0] CH0/CH1 calibrated + direct delay pipeline filled
    // IMPORTANT: experimental phase compensation does NOT establish
    // absolute source-clock sample alignment or guaranteed lossless FIFO.
    wire [3:0] single_ila_status = {
        cdc_drop_sync[1], cdc_valid,
        cdc_ready_sync[1], ch01_aligned_valid
    };

    adc_ila_12 u_ila_4ch (
        .clk   (adc_sample_clk[0]),
        .probe0(adc_twos_ch0_delayed),
        .probe1(adc_twos_ch1_delayed),
        .probe2(adc_twos_ch2),
        .probe3(adc_twos_ch3),
        .probe4(counter12),
        .probe5(single_ila_status)
    );

endmodule
