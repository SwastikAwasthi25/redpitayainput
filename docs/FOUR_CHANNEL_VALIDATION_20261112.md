# Four-channel ADC ILA capture validation — 12 November 2026

## Purpose and provenance

This record summarizes a new hardware observation on the Red Pitaya STEMlab 125-14 **4-Input** validation design. Two Vivado ILA captures were supplied from the programmed board: `hw_ila_1` for logical channels CH0/CH1 and `hw_ila_2` for logical channels CH2/CH3. Each capture contains **4,096 sample records**. They were **captured separately** rather than as a synchronized four-channel snapshot.

Both original Vivado `.ila` archives contained a `waveform.csv` entry. The exported samples were reanalyzed independently with a linear least-squares sine model, coarse frequency grid and scalar refinement, assuming a **125 MHz** sample clock and nominal **5 MHz** signal-generator setting. The numerical values below were reproduced by rerunning the archived analysis code against the original archives.

## Channel-level results

| Measurement | CH0 — ILA1 | CH1 — ILA1 | CH2 — ILA2 | CH3 — ILA2 |
|---|---:|---:|---:|---:|
| Fitted frequency (MHz)* | 5.000046 | 5.000067 | 5.000061 | 5.000087 |
| Single-tone sine-fit R² | **0.998580** | **0.998615** | **0.998488** | **0.998532** |
| Residual RMS (14-bit ADC codes) | 4.64 | 4.68 | 4.73 | 4.62 |
| Fitted sine peak amplitude (codes) | 174.12 | 177.69 | 171.88 | 170.47 |
| Fitted DC offset (codes) | +44.59 | +10.10 | +42.32 | +47.31 |
| Raw-to-signed RTL mapping | PASS | PASS | PASS | PASS |

*Frequencies are derived assuming the capture clock runs at 125 MHz; the absolute clock accuracy was **not independently calibrated**.

### Digital-capture integrity

| Check | ILA1 (CH0/CH1) | ILA2 (CH2/CH3) |
|---|---|---|
| Exported samples | 4,096 | 4,096 |
| 16-bit sample counter increments by +1 modulo 65,536 | **PASS**, all 4,095 transitions | **PASS**, all 4,095 transitions |
| Unique synchronized status | `0xF` | `0xF` |
| Raw/signed relationship | `signed = raw XOR 14'h1FFF` | `signed = raw XOR 14'h1FFF` |

The observed status flags correspond to both ADC clock-wizard lock indications, IDELAYCTRL ready, and calibration-ready. Their assertion verifies the recorded digital-status conditions, **not** a complete ADC electrical calibration.

## Integrity fingerprints

| Source artifact | SHA-256 |
|---|---|
| ILA1 original archive, `ila01data.ila` | `d7d03f39bd2c6ad7cd41cb18d496735d4e8c13ed19f8173b83cf47753f506c73` |
| ILA1 embedded `waveform.csv` | `fa652c57c0e5d46f0cfc2c5f06a110b3a3281b885fed4ef834eb528709111d36` |
| ILA2 original archive, `ila2_ch23_final_20261112.csv.ila` | `f95030b40f7a4bb40874b7d2d52a3790388ee194f1404ade3ff3b619b8786385` |
| ILA2 embedded `waveform.csv` | `f0de3fce3e931ed387a99c76d1bf87e880d5c449bdde5bcdc05e8b1bdfc1d5eb` |

The raw **November 12** archives/CSVs are retained separately with the captured laboratory evidence. This documentation update records their verified numerical analysis; it does not claim that the new raw files are included in the Git repository. Earlier original/corrected captures **are** checked into `evidence/data/`.

## Interpretation and limitations

**Verified from the records:** All four **logical** channels exhibit 5 MHz-consistent sinusoidal values; the formatting transformation is bit-exact; sample counters increment continuously; both sampled status vectors remain `0xF`. This materially extends the earlier one-channel corrected-waveform evidence.

**Not established by these captures:**

- Physical IN1–IN4/SMA-to-RTL channel mapping and individually controlled analog stimulus routing
- Generator voltage, impedance/load, attenuator positions, offset, or calibrated ADC amplitude
- True *simultaneous* four-channel acquisition, since the two ILA captures were obtained independently
- ADC datasheet-level ENOB, SINAD or THD; sine-fit R² is not any of these
- A final external ADC timing budget or comprehensive multi-corner CDC sign-off
- Which precise `.bit` file was programmed at capture time. In particular, **hardware retest of the fresh-clone-built bitstream is not proven** by a `.ila` archive alone

## Relation to existing evidence

The earlier firmware comparison in [README section 9](../README.md#9-what-was-broken-and-what-fixed-it) and [historical validation](VALIDATION.md) used the initial and corrected release captured on **different reported logical channels** (original CH1 and corrected CH0) and recorded sine-fit R² values of approximately 0.152454 and 0.999991 respectively. The **November 12 four-channel captures** constitute a new test with a different signal amplitude and must **not** be compared as if they were an identical experimental stimulus.

For the previously verified **fresh-clone synthesis/implementation** and its separate, untested-in-hardware bitstream, see [Fresh-Clone Vivado Build Verification](FRESH_CLONE_BUILD.md).
