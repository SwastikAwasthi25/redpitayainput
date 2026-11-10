# Hardware and RTL architecture

## Physical system

The tested Red Pitaya 4-Input platform has two Analog Devices LTC2145-14 dual-channel, 14-bit ADC devices. Their outputs are presented through four 7-lane DDR data paths (28 FPGA data inputs total) and two forwarded ADC clock pairs. The FPGA in the implemented project is `xc7z020clg400-1`; Vivado top-level RTL is `adc_system_top`.

## Observed Vivado hierarchy

These names were observed in the live project and ILA reports, **not invented source filenames**:

- `adc_system_top` → `u_adc_bridge` (`adc_spi_ila_bridge`)
- `u_adc_bridge/u_spi_init` for ADC SPI initialization
- `u_adc_bridge/u_adc_ila` (`adc_ila_top`)
- `u_adc_ila/u_frontend/u_adc_clocks` for forwarded clock buffering and clock wizard / IDELAY control
- `u_adc_ila/u_frontend/u_adc_capture/u_delay` for `IDELAYE2` input delays
- `u_adc_ila/u_frontend/u_adc_capture/u_ddr` for 28 IDDR instances
- `u_ila_12` and `u_ila_34` for dual ILA instrument clusters

One 125 MHz forwarded clock domain monitors channels 0–1, another monitors channels 2–3. A derived 200 MHz clock is used for IDELAY calibration logic. The PS FCLK is used for startup and SPI configuration; crossing logic requires CDC inspection.

## Reconstructed data

Each 14-bit sample uses 7 physical lanes with two bits per lane. The corrected local `adc_ddr_unpack.sv` was checked by the user after applying the code change:

```systemverilog
.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
.Q1(adc_raw[ch][2*bit_idx]),
.Q2(adc_raw[ch][2*bit_idx+1]),
```

Use of `SAME_EDGE_PIPELINED` affects data-path latency. The official ADC datasheet and clock polarity determine which Q phase maps to which ADC bit; the 5 MHz hardware capture confirms the **combined empirical correction** for the exercised path, not all future ADC configurations.

## ILA probes

| Core | Cell | Exported signals |
|---|---|---|
| `hw_ila_1` | `u_adc_bridge/u_adc_ila/u_ila_12` | `adc_raw[0]`, `adc_raw[1]`, `adc_signed[0]`, `adc_signed[1]`, `counter12`, `status12_sync` |
| `hw_ila_2` | `u_adc_bridge/u_adc_ila/u_ila_34` | `adc_raw[2]`, `adc_raw[3]`, `adc_signed[2]`, `adc_signed[3]`, `counter34`, `status34_sync` |

Status word `0xF` was observed on ILA1 but its exact constituent bit meanings are not inferred here without the implementation RTL. The `adc_signed` relation observed in CSV is `raw XOR 0x1FFF` in 14-bit representation; do not substitute an assumed datasheet coding mode for the actual source implementation.
