# Single-ILA four-channel ADC: IEEE 1241-oriented validation

**A reproducible ADC-only analysis package; no changes to FPGA RTL, CAL9, DMA, VDIF, old bitstreams or Vivado projects.**

**What is accomplished:** analyze a real Vivado .ila capture for 4 x signed 14-bit ADC streams; assert 4096 samples/channel, counter continuity, valid FIFO/readiness status, no sampled full-scale endpoint clipping; compute four-channel best-fitting 5 MHz sine metrics and relative apparent phase, residuals, plots and machine-readable records. 5 MHz / -20 dBm operator-reported input experiment: **functional engineering screen PASS**, NOT full IEEE 1241 compliance.

## File-by-file explanation

| File | Achieves |
|---|---|
| \`adc_4ch_validate.py\` | Read .ila ZIP or CSV; map CH0-CH3/probes; sign-correct 14-bit unsigned codes; verify indices, sample counter and status; fit sinusoids; produce diagnostic FFT, residuals, apparent phase, tables and graphs |
| \`test_adc_4ch_validate.py\` | Three offline synthetic/unit tests + five hardware integration tests (integration tests skip if original .ila is absent) |
| \`requirements.txt\` | Python dependencies: NumPy and Matplotlib |
| \`results/channel_metrics.csv\` | Exact reproduced per-channel metrics from 25 Nov original capture |
| \`results/capture_screening.json\` | Machine-readable provenance, checks, results and limitations |
| \`IEEE1241_PRELIMINARY_REPORT.md\` | Research-style method, observed results, interpretation and outstanding characterization tests |

**Original hardware archive not placed in this GitHub directory:** \`iladata(1).ila\`, SHA-256
\`bd594d609e60538df9a893a858cec5b3ad821329c12c77e81b2c72c6615502c1\`.
Retain it unmodified locally. GitHub results can be reproduced by supplying the exact hash-matching file.

## Windows instructions

1. Put \`iladata(1).ila\` beside \`adc_4ch_validate.py\`.
2. In PowerShell in this directory:

~~~powershell
python -m pip install -r requirements.txt
python -m unittest discover -v
python .\adc_4ch_validate.py --input ".\iladata(1).ila" --tone-hz 5000000 --generator-dbm -20 --out ".\recheck_01"
~~~

Use a **new output directory** for every additional run. For multiple captures at the **same nominal tone frequency**, repeat \`--input\`. For different nominal tones use separate commands/output folders.

### Expected on the 25-Nov evidence

- \`N=4096, counter errors=0, index errors=0, status={'0x7': 4096}\`
- \`FUNCTIONAL_ADC_CAPTURE_SCREEN: PASS\`
- \`NOT_IEEE_1241_CERTIFIED: YES\`

Outputs include \`capture_01/analysis.json\`, \`channel_metrics.csv\`, \`samples_measured_fitted_residual.csv\`, diagnostic FFT and measured-vs-fit plots, plus \`all_capture_comparison.csv\` for multiple independent records.

**Contributions:** This is a new additive, reproducible *analysis-only* package. It does not establish ADC-internal test-pattern bit-error reliability, IDELAY eye width, calibrated analog performance or four-channel physical sample synchrony. See \`IEEE1241_PRELIMINARY_REPORT.md\` for the full claims/evidence boundary.
