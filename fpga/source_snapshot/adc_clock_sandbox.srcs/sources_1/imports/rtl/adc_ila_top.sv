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

    // CH1 / CH2 ILA
    adc_ila_12 u_ila_12 (
        .clk   (adc_sample_clk[0]),
        .probe0(adc_raw[0]),
        .probe1(adc_signed[0]),
        .probe2(adc_raw[1]),
        .probe3(adc_signed[1]),
        .probe4(counter12),
        .probe5(status12_sync)
    );

    // CH3 / CH4 ILA
    adc_ila_34 u_ila_34 (
        .clk   (adc_sample_clk[1]),
        .probe0(adc_raw[2]),
        .probe1(adc_signed[2]),
        .probe2(adc_raw[3]),
        .probe3(adc_signed[3]),
        .probe4(counter34),
        .probe5(status34_sync)
    );

endmodule
