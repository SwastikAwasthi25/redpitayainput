# Fresh-Clone Vivado Build Verification

## Verified result

A fresh local Git clone was built in a separate Vivado 2025.2
project on Windows. The original working project was not reused.

Source commit: `c3228aaadec7cb293c185ba077a1c8ef2f885d18`

- Source integrity: 32 SHA-256 matches
- Python evidence test: PASS
- Block Design wrapper: generated from the original BD
- RTL synthesis: PASS
- Implementation and bitstream generation: PASS
- Global setup slack: 1.139 ns
- Global hold slack: 0.035 ns
- New bitstream and matching LTX: generated

## Rebuild from a GitHub clone

Install Vivado 2025.2, Git and Python.

Clone this repository into a directory without spaces.
For example:

```powershell
git clone https://github.com/SwastikAwasthi25/redpitayainput.git D:\redpitaya_adc_clone

New-Item -ItemType Directory D:\redpitaya_adc_build

& "D:\2025.2\Vivado\bin\vivado.bat" `
    -mode batch -nojournal `
    -source "D:\redpitaya_adc_clone\scripts\vivado_clean_rebuild.tcl" `
    -tclargs "D:\redpitaya_adc_clone" "D:\redpitaya_adc_build"
```

Adapt the Vivado executable path to the installation.

The script creates a new project using the cloned RTL, XCI,
BD and XDC files, regenerates IP outputs and the BD wrapper,
and runs synthesis, implementation, timing checks and
bitstream generation.

## Verification scope

The clean rebuild succeeded on the original Windows PC
from a separate local Git clone.

A rebuild on another computer has not yet been tested.
The newly rebuilt bitstream has not been independently
retested on hardware.

The separately included corrected_202 bitstream was
previously programmed and validated with a 5 MHz ILA capture.

ADC external timing constraints remain experimental.
Full four-channel characterization is not yet complete.