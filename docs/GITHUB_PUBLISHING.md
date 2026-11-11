# GitHub publication status and revision policy

The FPGA validation repository was **published to the existing public** GitHub repository:

**https://github.com/SwastikAwasthi25/redpitayainput**

The existing repository's MIT LICENSE and Git commit history were preserved. The owner reported permission to share this project publicly.

## Content that was published

- Actual exported FPGA RTL, XCI and BD, plus XDCs and a recorded SHA-256 provenance manifest (32 verified exported files)
- Corrected hardware-tested FPGA bitstream and matching LTX, and preserved original comparison pair
- Genuine 4,096-sample ILA exports, screenshots, numerical analysis and timing/DRC logs
- A successful source-based fresh **local clone** rebuild procedure in `scripts/vivado_clean_rebuild.tcl`
- A complete beginner-friendly [README](../README.md), including hardware limits and migration instructions

## Important limits

- The separately rebuilt bitstream was **not** subsequently reprogrammed for a new analog hardware test.
- External ADC input timing constraints remain experimental; full four-channel analog qualification remains pending.
- A clean rebuild on a **second** computer was not demonstrated.
- The historical `.xpr` contains the original developer's absolute project path; use the checked-in fresh rebuild script instead.

## Attribution warning

The **root MIT license does not supersede third-party rights**. In particular, `spi_master.v` contains a separate 2010 Instrumentation Technologies “All Rights Reserved” copyright notice. Keep that notice and establish redistribution rights as appropriate; AMD IP and institutional terms may also apply.

For future changes, commit to a reviewed branch, rerun evidence/source checks, and use an ordinary GitHub pull request. Do not force-push or rewrite the existing history. The old `scripts/publish_private.ps1` creates a separate repository and should **not** be used for maintaining this published repository.
