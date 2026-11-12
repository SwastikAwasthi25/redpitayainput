# Single-ILA ADC four-channel experiment: 8-cycle phase compensation (2026-11-12)

> **Source lineage:** `experiment/adc-direct-8clk-alignment-20261112`, integrated as a **separately selectable experimental RTL overlay** while preserving the original two-ILA source snapshot and release artifacts. **Status:** synthesized, placed/routed and tested on a Red Pitaya STEMlab 125-14 4-Input using Vivado 2025.2 and HS3 JTAG. This is **not** production CDC/ADC timing sign-off; merging the source into the repository does not qualify the image for deployment.

## Objective

Capture four signed 14-bit channels in **one** ILA clocked by the first ADC pair's forwarded clock, and measure the visible CH2/CH3 FIFO-induced *relative* phase offset. Test an experimental **eight-clock register pipeline on CH0/CH1** to compensate the approximately eight-sample observed shift. The pipeline is NOT intended to prove physical simultaneous sampling or the FIFO's absolute age.

## Architecture

- Two LTC2145-14 dual-channel ADCs; nominally 125 MHz forwarded sample clocks. `adc_sample_clk[0]` samples CH0/CH1; `adc_sample_clk[1]` samples CH2/CH3.
- CH2/CH3: 28-bit paired word through `xpm_fifo_async`, write clock 1, read clock 0; 2048 words, FWFT, two CDC sync stages, full/empty/busy controls, sticky source-drop monitor. Do not assume equal clock frequency over long periods.
- CH0/CH1: offset-binary to signed-14 conversion by `raw ^ 14'h2000`, then **8-stage, 14-bit/channel** ADC-clock-0 pipeline to ILA probes 0/1, introduced in experimental source commit `d654dc536d5899a5a632d1da48fb3e608bf19389`.
- CH2/CH3: FIFO output to ILA probes 2/3 without an additional alignment pipeline.
- Probe4: CH0/CH1 16-bit counter. Probe5: `[3]` sticky source drop synchronized; `[2]` FIFO valid; `[1]` source ready synchronized; `[0]` CH0/CH1 readiness plus full delay-pipeline validity.
- One six-probe `adc_ila_12` IP configured for 4096 samples; the `adc_ila_34` ILA is not instantiated. ILA clock is `adc_sample_clk[0]`.

```text
ADC chip A / CLK0 -> CH0+CH1 signed codes -> 8 x ADC0 registers ---------+
                                                                           | one ILA, CLK0
ADC chip B / CLK1 -> CH2+CH3 signed codes -> 28-bit async FIFO, read CLK0 -+
```

The 8 stages introduce **8 nominal CLK0 cycles = 64 ns** at 125 MHz; this is integer-sample visual phase compensation. The two ADC sampling clock phases, analog cabling, FIFO occupancy and absolute sample timestamps have not been calibrated.

## Actual 1 MHz hardware measurements

The analysis uses independently captured **4096 samples each** at nominal 125 MHz, before and after the 8-cycle change. Conversion is 14-bit two's complement; reported phase is a sine-fit apparent lag relative to CH0, not measured FIFO propagation delay.

| Channel | Before (sample lag vs CH0) | After (sample lag vs CH0) | After residual time |
|---|---:|---:|---:|
| CH0 | 0 (reference) | 0 (reference) | — |
| CH1 | -0.095 | -0.095 | -0.76 ns |
| CH2 (FIFO) | +7.767 | **-0.274** | **-2.19 ns** |
| CH3 (FIFO) | +7.744 | **-0.253** | **-2.02 ns** |

Sample offsets are estimated from fitted phase at 1 MHz. A 1 MHz sinusoid is periodic every ~125 ADC0 sample periods, so it cannot uniquely establish absolute FIFO delay. Earlier 5 MHz captures on the no-delay single-ILA trial yielded ~7.88-sample apparent CH2/CH3 shift; **a post-delay 5 MHz export remains pending**.

Both 1 MHz capture windows had 4095/4095 consecutive 16-bit counter increments (accounting for wrap) and `single_ila_status = 0x7` on all 4096 samples. This means source ready, FIFO valid, CH0/CH1 ready, and **no reported sticky drop during the captured window**; it does NOT prove indefinite losslessness. All four channels had sine-fit R² above 0.998 in those captures.

### ADC-code extrema (actual captured values)

| Capture | CH0 min / max | CH1 min / max | CH2 min / max | CH3 min / max |
|---|---|---|---|---|
| Before 8-cycle pipeline | -238 / +147 | -202 / +175 | -227 / +138 | -230 / +133 |
| After 8-cycle pipeline | -235 / +144 | -204 / +175 | -229 / +139 | -232 / +130 |

Full per-channel extrema, sample indices, means and peak-to-peak codes are in [the summary CSV](../evidence/analysis/adc_1mhz_before_after_min_max_summary.csv). The two full-size 4096-row CSVs and raw ILA captures have SHA256 identities below; **the raw files themselves are not tracked in this commit**, so the summary should not be mistaken for raw evidence.

| Capture | Raw capture SHA256 |
|---|---|
| Original 1 MHz `single_ila_1mhz_254.csv.ila` | `bcf31cd29083112487dd0930729dca91da75daba9fe201e3164604f4afcad4dc` |
| Aligned 1 MHz `iladata.ila` | `8aa8dbb74f65a853486bffcec4eb9e9370cea41f0f24b38d364fa31cb20becde` |
| Before `adc_1mhz_before_alignment_4096.csv` | `128c676308d3150678d62118671a6e742b122757eaa029bc7f0550972d263097` |
| After `adc_1mhz_after_8cycle_alignment_4096.csv` | `8b7a0aa44893d95f4835f64b6790f4cb1064f79ad26a0d8ca96c948eefc365f8` |

Use [`scripts/analyze_single_ila_alignment.py`](../scripts/analyze_single_ila_alignment.py) on the exported CSVs to regenerate extrema and sine-fit phase comparisons (requires Python + NumPy).

## Vivado 2025.2 implementation and reports

The routed experiment used source commit `d654dc5` in an isolated clone `D:/rp_adc_align8_clone_255`, build `D:/rp_adc_align8_synth_255`. These are example machine-local paths only.

| Check | Evidence / result |
|---|---|
| Synthesis-only | PASS; `SINGLE_ILA_SYNTH_ONLY_PASS` marker, matching source SHA |
| Post-route setup | WNS **+1.139 ns**, 0 failing endpoints |
| Post-route hold | WHS **+0.064 ns**, 0 failing endpoints |
| `report_bus_skew` | 8/8 reported groups meet 8.000 ns requirement, worst actual **1.041 ns**, minimum positive slack **+6.959 ns** |
| CDC | 15 CDC-3 and 2 CDC-9 **Info** (routed report); ADC1→ADC0 clock interaction still classified **Partial False Path (unsafe)** |
| DRC | 3 `PDCN-1569` warnings in `dbg_hub`; 1 `RTSTAT-10` warning including unused debug hub nets and an unused `xpm_fifo_async/overflow` output. No critical/error DRC violations in final checked implemented design |
| BRAM (pre-route synth utilization) | 11/140 block RAM tiles; 1297 LUTs; 2162 registers |
| Hardware | Experiment programmed through JTAG, **one ILA**, all four signed sinusoidal probes observed, actual phase shift reduced in 1 MHz capture |

**Interpretations and limitations:** Positive timing slack demonstrates compliance with *specified* constraints, not complete ADC interface sign-off. The 4 DRC warnings are unresolved rather than silently waived. Because report_clock_interaction marks ADC1→ADC0 unsafe/partial, production-grade CDC proof, FIFO rate drift, cross-clock sample age, input/board timing, output delays, resets, long-duration capture and exact analog channel calibration require independent review.

## Bitstream provenance and rollback

- Previous working single-ILA trial: `D:/rp_adc_single_ila_build_240/single_ila_4ch_trial.bit`, SHA256 `2CD92D46ADAE0DFFAB57652938B526A2AA6F4F25FC331078C7AA4D75D33D5A39`; paired `.ltx` hash `385D28FA8C6D44EE4B84886F5A870B7A817A2F7868DFCE59F5A8E2824A3AE944`. Previously verified available for rollback.
- Experimental phase-compensation bitstream `D:/rp_adc_align8_synth_255/align8_step273.bit`, SHA256 `6066FF1A08029E5132DCEBD40A293CE7341DE090C98FDD5313AD228B4B402009`.
- Experimental probes `D:/rp_adc_align8_synth_255/align8_step273.ltx`, SHA256 `2CE5D1678FAB21F460E2D724ABA4B508F77D7080E7815D44F25023A60EE6F829`.

These Windows paths identify the local build outputs; **this documentation does not imply that the bitstreams or LTX files were uploaded to GitHub**. Always use the matching .bit/.ltx pair. JTAG programming changes volatile FPGA configuration; neither flash nor the original two-ILA RTL snapshot/release was updated.

## Trigger experiment (19:33–19:39 IST, 2026-11-12)

Vivado screenshots show a signed `probe0` comparator value of `100` on the **delayed CH0 signal**, trigger position near 2048 of 4096, and Auto Re-trigger experiments. The visible status is `Waiting For Trigger` with 2048 pre-trigger samples. **These screenshots alone are not proof of a newly completed threshold-event capture**, continuous gap-free streaming, or any new latency correction. Exact comparison operator, crossing direction and saved timestamp must be confirmed before claiming crossing-based triggering.

## How to reproduce

1. Select the experimental RTL overlay and run a new clean clone/build. Never modify the archived original source snapshot or known-good release bitstream.
2. The existing `scripts/vivado_single_ila_synth_only.tcl` creates an isolated Vivado 2025.2 project from exported RTL/IP/BD/XDC and substitutes the overlay `variants/single_ila_4ch/adc_ila_top.sv`. Review synthesis/CDC and route/timing/DRC/bus-skew reports before generating a candidate bitstream.
3. With the board on verified safe analog levels, program candidate JTAG bitstream with **matching** LTX; verify exactly one ILA and signal status `0x7`.
4. Export 4096 samples at known generator frequency; use [the analyzer](../scripts/analyze_single_ila_alignment.py) to compare channel phase and check counter/status.
5. For 100-code threshold experiments, distinguish an ordinary equality/level comparator from true rising-edge crossing `previous < threshold && current >= threshold`. A trigger controls recording location; it does not remove FIFO latency.

## Outstanding work

- Repeat after-delay **5 MHz** hardware capture and compare against baseline.
- Long-running continuous capture/FIFO-depth monitoring, backpressure/overflow and frequency-drift tests.
- Absolute sample age and cross-chip sample-instant alignment using common reference/markers, not periodic sine alone.
- Independently review CDC clock interaction, ADC input setup/hold budget, unresolved DRC and unconstrained I/O before deployable sign-off.
- Keep this variant explicitly experimental even when source/documentation resides on the default Git branch; do not replace the verified two-ILA release or deploy the experimental bitstream until remaining checks pass.
