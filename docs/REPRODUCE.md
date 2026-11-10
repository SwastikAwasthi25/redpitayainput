# Recreate, inspect, and test the exact Vivado design

## 1. Local source export (Windows)

Run the supplied `collect_from_windows.ps1` script from this repo's root after checking its source and destination paths. It checks that the local DDR RTL is the **tested corrected version**, copies the original `.xpr` and `.srcs` without modifying them, and imports the actual two trial XDCs, timing reports, release bitstreams, and probes. It creates a SHA-256 manifest and stops rather than invent missing source. The export script never rebuilds or overwrites the hardware project.

## 2. Create a native Vivado recreation Tcl

With the original `adc_clock_sandbox.xpr` open in Vivado 2025.2, run the following in the **Vivado Tcl Console**, using an appropriate path to the exported repository:

```tcl
set repo {D:/path/to/redpitaya-4ch-adc-validation}
write_project_tcl -force "$repo/fpga/recreate_project_from_vivado.tcl"
```

This produces a Vivado-generated description of the current project, instead of a guessed source list. Check external absolute paths and tool/IP version warnings before using it on a second machine. For a more comprehensive snapshot, use **File → Project → Archive** (Vivado UG895), selecting the appropriate source and generated IP options. Never imply `.xpr` alone is guaranteed portable.

## 3. Validate exact source build

In Vivado on the Windows PC, verify the original recorded runs and files first:

- `synth_adc_fix_200`: `synth_design Complete!`
- `impl_adc_fix_200`: `route_design Complete!`
- Input-delay XDC registered for implementation: `adc_ddr_trial_184.xdc`
- Implementation-only CDC XDC: `adc_cdc_verified_199.xdc`
- Actual bitstream: `adc_ddr_corrected_202.bit`
- Actual debug probes: `adc_ddr_corrected_202.ltx`

In a **separate clone** of the project, regenerate local IP as needed, run synthesis and implementation, inspect `report_timing_summary`, `report_drc`, and `report_bus_skew`, then generate bitstream. Compare the resulting outputs with the original export manifest, taking into account non-deterministic implementation results. **No clean cloned-project rebuild is claimed in this repository yet.**

## 4. Test hardware safely

1. Keep analog generator output OFF and check the board's LV/HV attenuator setting and permitted input voltage.
2. Use the known-good HS3 JTAG connection to the correct `xc7z020_1` device. Power-cycle before reprogramming if necessary.
3. Load the matching `.bit` and `.ltx` release from `fpga/releases/corrected_202/` in Vivado Hardware Manager.
4. Verify startup HIGH and two ILA cores, without bypassing DRC or loading unrelated DMA/VDIF firmware.
5. Apply the known 5 MHz sine at a verified safe level to one explicitly logged SMA input.
6. Trigger `hw_ila_1` and export its actual ILA capture using `write_hw_ila_data -csv_file`.
7. Analyze the CSV and record the input channel, signal amplitude, offset, frequency, waveform shape, and all ILA clock settings.

Keep the experimental release separate from production FPGA builds. No PS/Linux DMA or network output is included in this validation scope.
