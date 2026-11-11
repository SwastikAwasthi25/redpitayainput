# Hardware validation and measured evidence

## Precisely verified scope

This repository contains two *real*, 4,096-sample ILA1 CSV exports from the Red Pitaya 125-14 4-Input FPGA validation sandbox, plus the corrected 202 bitstream and its matching probes.

- Board: Red Pitaya STEMlab **125-14 4-Input** (XC7Z020).
- Vivado: **2025.2** on Windows, Digilent HS3 JTAG.
- Original firmware: `fpga/releases/original_169/adc_validation_trial.bit`.
- Corrected, **hardware-tested** firmware: `fpga/releases/corrected_202/adc_ddr_corrected_202.bit`.
- Corrected JTAG programming succeeded; startup reported **HIGH**; **two ILA cores** were enumerated.
- A separate **fresh local Git clone** of source commit `c3228aaadec7cb293c185ba077a1c8ef2f885d18` was independently synthesized, implemented, and generated a *new* bitstream and matching LTX on the same Windows computer. **The new bitstream has not been separately hardware-tested.** See [fresh-clone build](FRESH_CLONE_BUILD.md).

## Original vs corrected capture

| Measurement | Original signed CH1 | Corrected signed CH0 |
|---|---:|---:|
| Sample rows | 4096 | 4096 |
| Nominal generator sine | 5 MHz | 5 MHz |
| Frequency fitted assuming 125 MHz ILA rate | 5.000182 MHz | 5.000064 MHz |
| Single-tone sine fit R² | 0.152454 | 0.999991 |
| Residual RMS | 3459.83 codes | 9.50 codes |
| Counter modulo-65536 continuity | PASS | PASS |
| Synchronized ILA1 status | 0xF | 0xF |

The original strongest signal appeared on **logical CH1**, while the corrected sine was measured on **logical CH0**. Physical SMA port, stimulus amplitude, attenuator position, offset, and connection changes were *not independently recorded*. This is not a calibrated, same-channel before/after test. A high R² is **not** a datasheet THD/ENOB or SINAD measurement.

The 125 MHz sample rate is consistent with the experimental clocking configuration but has not been separately calibrated for absolute frequency accuracy.

## Reproduce from repository contents

```powershell
python -m pip install -r requirements.txt
python scripts/verify_export.py --require-source
python scripts/analyze_capture.py --old evidence/data/original_5mhz_ch01.csv --new evidence/data/corrected_5mhz_ch01.csv --output evidence/results
python -m unittest discover -s tests -v
```

For a fresh **Vivado** rebuild, follow [README section 12](../README.md#12-clone-test-and-rebuild-a-bitstream). Do not open the copied historical `.xpr` expecting machine-portable absolute paths.

## Status bit map (verified from adc_ila_top.sv)

- Bit 0: Clock Wizard 01 locked
- Bit 1: Clock Wizard 23 locked
- Bit 2: IDELAYCTRL ready
- Bit 3: Calibration ready

All bits were high in the recorded ILA1 captures. This indicates that the *reported internal flags* were asserted, not comprehensive ADC board qualification.

## Not yet done

- Controlled CH0–CH3 (IN1–IN4) port-to-channel mapping and four-channel analog measurements
- Documented generator amplitude, voltage range, attenuator, load and offset
- Independent second-PC Vivado rebuild
- Hardware retest of the separately rebuilt bitstream
- Validated external timing budget across board/ADC delay and operating corners
- Production CDC/metastability, DRC and methodology review

The project is a **hardware-derived validation sandbox**, not full ADC-to-DDR DMA, VDIF or UDP streaming firmware.
