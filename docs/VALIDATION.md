# Hardware validation and measured evidence

## Setup recorded from the experiment

- Board: Red Pitaya STEMlab 125-14 **4-Input** with XC7Z020 FPGA.
- Tool: Vivado 2025.2 on Windows, Digilent HS3 JTAG.
- Firmware #1 (initial): `adc_validation_trial.bit` and matching `.ltx` from local Step 169/170.
- Firmware #2 (corrected): `adc_ddr_corrected_202.bit` and matching `.ltx` from local Step 202.
- Signal source: nominal 5 MHz sine wave, amplitude and connector placement **not independently recorded**.
- Scope: ILA1 captured 4096 samples each; ILA 125 MHz rate is assumed from clocking constraints and should be verified for calibrated absolute-frequency claims.

## Original capture

Source: `evidence/data/original_5mhz_ch01.csv`, corresponding to Vivado Step 179. CH1 exhibited periodic but distorted readings. Dominant FFT **bin** of the signed CH1 capture was ~15.01465 MHz. Fitted single 5 MHz tone explained 15.245% of code variance.

## Corrected capture

Source: `evidence/data/corrected_5mhz_ch01.csv`, corresponding to Vivado Step 205. CH0 showed a smooth sine. Dominant FFT **bin** was ~5.00488 MHz; interpolated regression frequency was ~5.000064 MHz. A single-tone sinusoid explained 99.99914% of measured variance; RMS residual 9.50 ADC codes.

The two files are actual ILA exports with per-sample counters; sample indices run 0 through 4095 and counter values increment modulo 65536. Both show `status12_sync` = `0xF` throughout. A channel swap in observations between experiments is **unexplained pending confirmation of physical SMA input and RTL mapping**; avoid claims of identical-channel A/B comparison.

## Reproduction

```bash
python -m pip install -r requirements.txt
python scripts/analyze_capture.py --old evidence/data/original_5mhz_ch01.csv --new evidence/data/corrected_5mhz_ch01.csv --output evidence/results
python -m unittest discover -s tests -v
```

The generated `metrics.json` records capture identity, source frequency assumptions, sample count, fit, and evidence-specific limitations. It is not a general-purpose ADC datasheet qualification report.

## Verification coverage

| Check | Observed |
|---|---|
| FPGA JTAG programming | Successful, startup HIGH |
| ILA cores enumerated | 2 |
| Original + corrected CH0/CH1 captures | 4096 samples each |
| 5 MHz corrected waveform | High-quality sine fit on CH0 |
| Continuous captured counter | Yes, both files |
| CH2/CH3 generator tests | Not documented |
| Input amplitude / gain calibration | Not documented |
| Multi-temperature / voltage corner testing | Not performed |
| Clean exported-project rebuild | Must be run after local source export |

## Next laboratory work

Confirm physical input-to-channel correspondence, test all four SMA inputs at known amplitudes (begin within the verified LV/HV range), repeat capture at several frequencies, and derive external timing constraints using ADC/PCB clock-data skew rather than treating the present trial values as production-qualified.
