# IEEE 1241-2023-aligned preliminary characterization: four-channel ADC

**Recorded 25 Nov 2026. Scope: ADC-only four-channel Red Pitaya STEMlab 125-14 4-Input.**

> **VERDICT: functional engineering screening PASS. NOT an IEEE 1241 certification, calibrated ADC characterization, or production timing sign-off.**

## Capture provenance and method

- Firmware: experimental **align8_step273**, as reported by operator; firmware identity not authenticated by the ILA file itself.
- Single Vivado ILA: **4,096 samples/channel**, nominal **125 MSPS**, **14-bit two's-complement**.
- Stimulus: operator-reported **5 MHz sine, -20 dBm** generator setting. Analog voltage at the ADC pins **not independently measured**. Generator frequency and ADC sample-clock accuracy not independently calibrated.
- Original capture: **iladata(1).ila**; SHA-256 **bd594d609e60538df9a893a858cec5b3ad821329c12c77e81b2c72c6615502c1** (raw capture retained separately; not committed in GitHub).
- Code reads the \`waveform.csv\` member inside the .ila archive or an exported CSV, converts 14-bit unsigned/display codes to signed values, verifies sample indices and 16-bit counter wrap, checks status and clipping endpoints, fits a sine independently on CH0-CH3, and saves per-sample measured/fitted/residual data, metrics, plots and provenance.

The measured samples are compared to a **sine fitted from those same samples**, not to an externally calibrated per-sample ADC reference. This is a useful functional screen but cannot prove every digital bit is error-free.

## Directly reproduced results

| Property | Observation |
|---|---|
| 4 channels / sample count | 4 x 4,096 |
| Sample-index discontinuities | **0** |
| 16-bit counter discontinuities | **0** out of 4,095 successive transitions; normal modulo-65,536 wrap |
| FIFO/readiness status | **0x7** for all 4,096 samples |
| Unexpected status records | **0** |
| 14-bit endpoint code clipping (-8192, +8191) | **0** observed samples |
| Functional screen | **PASS**: each R-squared >= 0.99 and peak amplitude >= 20 codes (project thresholds; NOT IEEE limits) |

| Channel | Fitted f (MHz) | Amplitude peak (codes) | DC offset (codes) | R-squared | Residual RMS (codes) | Apparent lag vs CH0 (samples) |
|---|---:|---:|---:|---:|---:|---:|
| CH0 | 5.000077 | 173.71 | -47.28 | 0.998478 | 4.79 | 0.000 |
| CH1 | 5.000066 | 176.32 | -14.40 | 0.998574 | 4.71 | -0.063 |
| CH2 | 5.000070 | 171.54 | -44.76 | 0.998458 | 4.77 | -0.212 |
| CH3 | 5.000055 | 170.04 | -49.33 | 0.998415 | 4.79 | -0.189 |

Apparent lags refer to a **periodic 5 MHz sine**, not absolute channel skew. CH0/CH1 are delayed eight ADC0 cycles in the experimental RTL; CH2/CH3 cross an asynchronous FIFO. The values do not prove four physically simultaneous samples.

## Remaining IEEE 1241-oriented work (NOT measured)

1. **Physical digital-link bit correctness:** ADC-chip checkerboard/alternating test-pattern comparisons on CH0-CH3 and IDELAY tap/error-free-eye characterization.
2. **Analog setup qualification:** input LV/HV and measured board-input voltage/impedance, external signal purity, measured ADC clock, physical SMA-to-logical channel mapping.
3. **DC/dynamic ADC characteristics:** input-terminated noise; full-scale amplitude and gain/offset; calibrated SNR, SINAD, SFDR, THD and ENOB with suitable signal and sample conditions; DNL/INL and missing-code histograms.
4. **Multi-channel reliability:** clock/FIFO drift, reset recovery, long-duration drops, phase coherence, cross-channel skew, bandwidth, crosstalk and repeatability.

**Caution:** RMS sine-fit residual (4.71-4.79 ADC codes) includes generator noise, harmonics, analog front end and sampling imperfections. It is **not** independently measured ADC-only SNR, SINAD, ENOB or SFDR. A status of 0x7 means no **reported** FIFO drops during this one 4,096-sample window; it is not evidence of indefinite lossless streaming.

## References

- IEEE Std 1241-2023, Standard for Terminology and Test Methods for Analog-to-Digital Converters: https://standards.ieee.org/ieee/1241/6797/
- Analog Devices LTC2145-14 datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/21454314fa.pdf
- Baseline architecture: https://github.com/SwastikAwasthi25/redpitayainput
