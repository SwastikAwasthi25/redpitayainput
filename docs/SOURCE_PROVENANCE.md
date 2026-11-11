# Source provenance and integrity

**Verified historical export:** The source snapshot in this public repository is from the original Windows Vivado 2025.2 validation sandbox, not a reconstructed or inferred copy. The Windows exporter copied and SHA-256-checked **32 files**, including source, IP configuration, XDCs, original/corrected .bit/.ltx releases and available reports.

The Git index was checked to preserve the original bytes of all 32 manifest-tracked files. The manifest lives at `fpga/provenance_manifest.csv`.

- `fpga/source_snapshot/adc_clock_sandbox.srcs/`: checked-in actual RTL, XCI, BD and board XDC
- `fpga/source_snapshot/adc_clock_sandbox.xpr`: historical project metadata (contains original PC absolute path; **not portable**)
- `fpga/external_constraints/`: trial clock, DDR input-delay and targeted CDC XDCs
- `fpga/releases/corrected_202/`: previously programmed, hardware-tested corrected bitstream and matching LTX
- `fpga/releases/original_169/`: original comparison bitstream and probes
- `evidence/reports/`: available original Vivado run logs and timing/DRC reports

## Verify a fresh clone

```powershell
git clone https://github.com/SwastikAwasthi25/redpitayainput.git D:\redpitaya_adc_clone
cd D:\redpitaya_adc_clone
python scripts/verify_export.py --require-source
```

Expected: `SOURCE_EXPORT: VERIFIED (32 hash-matched files; corrected DDR source present)`.

**Do not rerun the historical** `scripts/collect_from_windows.ps1` **on another computer**: its original purpose was copying from a particular Windows sandbox; it is unnecessary for this complete repository.

A separate **clean local clone** of the exported sources was successfully rebuilt with Vivado 2025.2 using `scripts/vivado_clean_rebuild.tcl`. See [FRESH_CLONE_BUILD.md](FRESH_CLONE_BUILD.md). This was on the original PC; it does not prove portability to a different tool installation or physical board. The independently rebuilt bitstream was not separately hardware-tested.

The manifest confirms exact file identity, not absolute correctness of the interface timing constraints, third-party redistribution rights or a complete four-channel analog qualification. Review those separately.
