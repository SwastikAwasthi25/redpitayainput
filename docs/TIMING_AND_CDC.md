# Timing constraints, CDC handling, and limitations

## Measured routed trial (Vivado `impl_adc_fix_200`)

| Check | Reported result |
|---|---:|
| Setup WNS | +1.139 ns |
| Hold WHS | +0.035 ns |
| Setup/hold failing endpoints | None in final reported timing check |
| Bus skew constraints | Four reported checks positive |
| Bitstream output | 4,045,690 bytes |
| Debug probes `.ltx` | 41,511 bytes |

These results were reported during the corrected implementation built from `synth_adc_fix_200` → `impl_adc_fix_200`. The actual local `step200_timing_summary.rpt`, design checkpoint, and Vivado project state must be exported from the PC for independent inspection.

### Experimental external input delay model

Two 14-lane groups were constrained to their respective 125 MHz ADC clock with a trial `set_input_delay -min 2.0`, `-max 2.6` ns, both rise and fall edges. The trial file is `adc_ddr_trial_184.xdc`. These numbers were selected during a bring-up investigation; they do **not** independently prove board-level setup/hold margin. Proper sign-off requires the LTC2145-14 timing definitions, 270-degree phase setting, package and PCB clock/data skew, IDELAY calibration, I/O jitter, and input-voltage mode.

### CDC first stages

There were setup violations from a 200 MHz calibration-ready register to the first stage of two 125 MHz status synchronizers:

- `status12_meta_reg[3]` (setup -1.636 ns before exception)
- `status34_meta_reg[3]` (setup -1.468 ns after first exception)

Both first- and second-stage `ASYNC_REG` properties were checked true and each checked first-stage Q fed only the corresponding second-stage D. The implementation-only `adc_cdc_verified_199.xdc` applies **targeted** `set_false_path` exceptions to those first-stage destinations. Excluding synchronization paths from ordinary setup timing does not change physical propagation delay or prove MTBF; evaluate clock relationship and CDC timing/routing robustness separately. The XDC line was applied as an experimental CDC modeling decision, not as a general waiver of cross-clock paths.

### Other issues observed during debugging

- An early XDC accidentally used unsupported procedural `foreach` syntax and was rejected by Vivado; the source was corrected in Step 192. The repository must include the corrected **actual** file, not the invalid backup.
- Initial GUI "Failed Timing" showed original default runs; the corrected active runs were checked `NEEDS_REFRESH=0` and implementation complete.
- A prior OOC IP warning `Failed to create directory 'C'` was seen in a log and should be reviewed in a clean rebuild; final successful run does not certify every IP source is portable.
- Independent CDC, DRC, unconstrained-output, and methodology audits are still required for production sign-off.
