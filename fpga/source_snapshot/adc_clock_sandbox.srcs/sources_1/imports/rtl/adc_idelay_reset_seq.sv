`timescale 1ns / 1ps

module adc_idelay_reset_seq (
    input  wire clk_ref_200,
    input  wire startup_resetn,
    input  wire clk_ref_locked,
    input  wire idelay_ready,

    output wire idelay_rst,
    output wire calibration_ready
);

    // Upstream Clock Wizard is already reset when startup_resetn is low.
    // Its LOCKED signal is used directly for async reset assertion.
    // Reset release is synchronized to the 200 MHz reference clock.
    (* ASYNC_REG = "TRUE" *) logic [2:0] release_sync;

    always_ff @(posedge clk_ref_200 or negedge clk_ref_locked) begin
        if (!clk_ref_locked)
            release_sync <= 3'b000;
        else
            release_sync <= {release_sync[1:0], 1'b1};
    end

    // 64 cycles at 200 MHz = 320 ns.
    logic [6:0] reset_count;

    always_ff @(posedge clk_ref_200) begin
        if (!release_sync[2])
            reset_count <= 7'd0;
        else if (reset_count < 7'd64)
            reset_count <= reset_count + 7'd1;
    end

    // IDELAYCTRL RST is an asynchronous input. A registered source
    // avoids a multi-input LUT directly driving this reset pin.
    // The register asserts immediately if MMCM lock is lost; after lock
    // it holds reset high for >=64 stable 200 MHz cycles.
    logic idelay_rst_reg;

    always_ff @(posedge clk_ref_200 or negedge clk_ref_locked) begin
        if (!clk_ref_locked)
            idelay_rst_reg <= 1'b1;
        else
            idelay_rst_reg <= !release_sync[2] || (reset_count < 7'd64);
    end

    assign idelay_rst = idelay_rst_reg;

    // This status belongs to the 200 MHz domain.

    // Synchronize IDELAYCTRL READY to the 200 MHz reference domain.
    (* ASYNC_REG = "TRUE" *) logic [1:0] idelay_ready_sync;
    logic calibration_ready_reg;

    // Synchronize external IDELAYCTRL READY.
    always_ff @(posedge clk_ref_200) begin
        if (!release_sync[2])
            idelay_ready_sync <= 2'b00;
        else
            idelay_ready_sync <= {idelay_ready_sync[0], idelay_ready};
    end

    // Use the locally synchronized reset release.
    always_ff @(posedge clk_ref_200 or negedge release_sync[2]) begin
        if (!release_sync[2])
            calibration_ready_reg <= 1'b0;
        else
            calibration_ready_reg <=
                (reset_count == 7'd64) &&
                idelay_ready_sync[1];
    end

    assign calibration_ready = calibration_ready_reg;

endmodule
