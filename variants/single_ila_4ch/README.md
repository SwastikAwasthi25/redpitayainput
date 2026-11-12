# Experimental single-ILA four-channel two's-complement capture

**Experiment status (2026-11-12):** The **8-cycle-compensation overlay** passed synthesis/routing and was tested on 1 MHz hardware through a single ILA. The prior single-ILA feature branch has a separate, non-delayed variant. Neither is a production-signed-off design. See [detailed results](../../docs/SINGLE_ILA_8CYCLE_ALIGNMENT_20261112.md).

The original professor-facing **two-ILA source snapshot and release artifacts** are unchanged. This is a separate selectable design variant implemented as an `adc_ila_top.sv` **overlay**. The original 32 SHA-256-tracked source/release/report artifacts stay untouched.

## Goal

Display **four 14-bit two's-complement ADC channels in one Vivado ILA core**, rather than two independent ILA cores with two channels each. The external ADC chips are configured by existing `adc_spi_init.sv`. Under its existing A4 register setting of `0x00` the ADC data is offset-binary; convert to true 14-bit two's-complement by **toggling the MSB**, i.e. `two_s = raw ^ 14'h2000`. This is **not** the existing project's legacy `adc_signed = raw ^ 14'h1FFF` transformation.

## Clock domains and data safety

- CH0/CH1: sampled by ADC clock pair 0 at nominal 125 MHz; their conversion and ILA probe connections stay in clock domain 0.
- CH2/CH3: sampled by ADC clock pair 1 at nominal 125 MHz; the **two-channel 28-bit word** passes through a depth-2048 AMD `xpm_fifo_async` into clock domain 0.
- A single existing six-probe `adc_ila_12` IP configuration is reused, clocked by `adc_sample_clk[0]`. The second `adc_ila_34` instance is **not instantiated** in this variant.
- The FIFO is **first-word-fall-through** and is drained whenever ready in the destination domain. FIFO **empty**, **reset-busy** and source-domain **full** are monitored.
- Source readiness and drop-status flags are synchronized as *single-bit controls*; the **sample data crosses only through the asynchronous FIFO**. If a source sample pair cannot be enqueued because the FIFO is full, a sticky drop flag is set. This trial does **not** claim lossless indefinite throughput at nominally equal but independently drifting 125 MHz clocks.

### One ILA's six probe buses

| Probe | Width | Value |
|---|---:|---|
| `probe0` | 14 | CH0 two's-complement sample **after 8 CLK0 cycles** |
| `probe1` | 14 | CH1 two's-complement sample **after 8 CLK0 cycles** |
| `probe2` | 14 | CH2 two's-complement sample after asynchronous FIFO |
| `probe3` | 14 | CH3 two's-complement sample after asynchronous FIFO |
| `probe4` | 16 | Native CH0/CH1 sample-clock counter |
| `probe5` | 4 | bit 3: synchronized FIFO-drop sticky; bit 2: FIFO data valid for probes 2/3; bit 1: synchronized CH2/CH3 source readiness; bit 0: CH0/CH1 calibrated **and direct 8-cycle pipeline filled** |

**Important:** An 8-cycle register pipeline helps visually compensate the measured sine-wave phase but **does not prove all four ADC samples correspond to one physical sampling instant**. A line at a particular ILA sample index is **not necessarily a simultaneous 4-channel ADC sampling instant**. Samples CH2/CH3 pass through a FIFO, and the apparent delay can vary with clock phase, occupancy, and sampling conditions; direct channels on this branch use a fixed 8-cycle compensation. To prove cross-pair phase coherence or simultaneity requires timestamps, clock relationship analysis, elastic buffering/clock alignment, and appropriate measurement. **CDC validation must not be skipped before hardware use.**

### Read the signed probes properly

In Vivado Hardware Manager choose `Signed Decimal` and analog wave plotting with a suitable fixed Y range for probes 0–3. This changes the *display interpretation* only; the RTL performs the true offset-binary→two's-complement conversion.


### Experiment-specific evidence and build note

The trial-builder commands below are for **fresh independent builds** with new output folders. They do not reproduce the exact historical local paths used in the 2026-11-12 alignment hardware experiment. That hardware test used source commit `d654dc5`, `scripts/vivado_single_ila_synth_only.tcl`, then a separate routed Vivado run and bitstream/probe export; hashes, timing, warnings, phase analysis and outstanding gates are recorded in the [dated experiment report](../../docs/SINGLE_ILA_8CYCLE_ALIGNMENT_20261112.md).

For the variant's actual firmware, refer to `adc_twos_ch0_delayed` and `adc_twos_ch1_delayed`; do not confuse them with non-delayed probe labels in older screenshots or documentation.

## Build the experimental variant on Windows

Prerequisites: same as the original successful clean clone (Vivado **2025.2**, correct FPGA device support, Git). Use **space-free paths**, and a new output directory separate from any historical builds:

```powershell
git clone --branch experiment/adc-direct-8clk-alignment-20261112 https://github.com/SwastikAwasthi25/redpitayainput.git D:\rp_adc_single_ila_trial
New-Item -ItemType Directory -Path D:\rp_adc_single_ila_build

python D:\rp_adc_single_ila_trial\scripts\verify_export.py --require-source

& "D:\2025.2\Vivado\bin\vivado.bat" -mode batch -nojournal -log "D:\rp_adc_single_ila_build\vivado.log" -source "D:\rp_adc_single_ila_trial\scripts\vivado_single_ila_trial.tcl" -tclargs "D:\rp_adc_single_ila_trial" "D:\rp_adc_single_ila_build"
```

This trial builder reuses the existing, verified `vivado_clean_rebuild.tcl` procedure but **replaces only the copy of `adc_ila_top.sv` in the fresh project source list** with `variants/single_ila_4ch/adc_ila_top.sv`. It does not mutate the original `fpga/source_snapshot` or historical bitstreams.

If implementation succeeds and detailed CDC/timing/DRC review is acceptable, the trial outputs are:

- `D:\rp_adc_single_ila_build\adc_system_top_single_ila_trial.bit`
- `D:\rp_adc_single_ila_build\adc_system_top_single_ila_trial.ltx`
- `timing_summary.rpt`, `bus_skew.rpt`, `drc.rpt` and `cdc_review.rpt`
- `SINGLE_ILA_TRIAL_BUILD_PASS.txt` (a **build-only** marker; does **not** certify CDC sign-off or actual hardware)

### Required review before JTAG programming

1. Ensure single-ILA hierarchy, four two's-complement probe buses, 28-bit FIFO width, two separate sample clocks, correct reset sequencing and no stale cached IP.
2. Review synthesis/implementation warnings and output `report_cdc`/`report_timing_summary`/`report_drc`. Check FPGA resources and clock constraints; no blanket false-path exception should hide sample bus crossings.
3. Check FIFO full/empty/busy behavior with two clocks whose relative frequencies differ slightly; determine whether continuous samples can be lost and how to document the drop flag.
4. Confirm that XPM/FPGA primitive connectivity meets Vivado 2025.2 design-rule checks; further changes may be required. This overlay has been **synthesized, routed, and hardware-tested at 1 MHz** as recorded in the dated experiment report. Further CDC and production sign-off remain required.
5. **Do not program experimental hardware before the above checks pass.** Keep the previously tested corrected bitstream in `fpga/releases/corrected_202/` as the known-good fallback.

## Why not just wire CH2/CH3 into one ILA?

Vivado ILA has a **single capture clock**. Sampling a multi-bit, continuously changing data bus directly from another unrelated clock domain risks incoherent reads and metastability. A two-flop synchronizer applied *per bit* is also **not** a safe way to preserve a multi-bit ADC word. The asynchronous FIFO is an explicit crossing mechanism; it remains subject to throughput, reset, and validation constraints.

## Follow-up work

For further controlled hardware testing: review CDC, inspect the single ILA on hardware, validate that `probe5[2]` (data valid) and `probe5[3]` (FIFO dropped data) behave as expected, capture all four two's-complement values, and compare with the earlier two-ILA baseline. This is **an experimental design variant**, not a retrospective claim that the published hardware tests were done with one ILA.
