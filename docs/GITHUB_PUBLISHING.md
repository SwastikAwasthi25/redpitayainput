# GitHub Publication

## Repository

Existing repository:
https://github.com/SwastikAwasthi25/redpitayainput

The existing main branch contains an MIT LICENSE.
Its history must be preserved.

The actual FPGA source and measurement evidence have been
integrated into the local adc-validation-review branch.

## Verified

- 32 exported files passed SHA-256 verification.
- Corrected IDDR source was verified.
- Automated evidence analysis passed.
- Corrected FPGA bitstream was programmed via JTAG.
- Two ILA cores were detected.
- A corrected 5 MHz sine-wave capture was obtained.

## Limitations

- Independent clean Vivado rebuild is not yet verified.
- Four-channel analog operation is not fully validated.
- External ADC input-delay assumptions require final review.
- Physical channel mapping is not fully confirmed.
- Vendor IP and institutional redistribution permissions
  require manual confirmation.
- The original XPR contains a machine-specific project path.

## Publication Policy

Do not overwrite the existing MIT LICENSE.
Do not force-push or rewrite existing Git history.

Before any public upload, review intellectual-property
ownership, third-party IP licenses, institutional approval,
and the visibility of the destination repository.

The existing MIT license does not automatically grant
redistribution rights for third-party or institutional IP.

After approval, publish the reviewed local branch and
merge it into main through the normal GitHub review process.

Do not use scripts/publish_private.ps1: it is intended
for creating a separate repository.

## Scientific Scope

This repository documents an experimentally validated
ADC DDR reconstruction correction. It is not a claim
of production readiness or complete four-channel sign-off.