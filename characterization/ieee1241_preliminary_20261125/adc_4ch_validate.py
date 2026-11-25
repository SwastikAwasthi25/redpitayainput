#!/usr/bin/env python3
"""Independent, read-only four-channel ADC ILA validation.

Supports Vivado .ila (ZIP archive containing waveform.csv) or exported waveform.csv.
Hardware target: Red Pitaya 125-14 4-Input, align8_step273 single-ILA
(CH0/CH1 delayed 8 ADC0 clocks; CH2/CH3 through asynchronous FIFO).

Reports capture integrity, per-channel sine fitting, residuals, apparent phase,
and reproducible plots. NOT IEEE 1241 SNR/SINAD/ENOB, ADC timing sign-off,
absolute channel simultaneity, or ADC test-pattern bit-error proof.

Requirements: Python 3.10+, numpy, matplotlib. No scipy required.

Example:
  python adc_4ch_validate.py --input "D:\\captures\\iladata.ila" \
      --tone-hz 5000000 --generator-dbm -20 \
      --out "D:\\captures\\analysis_20261125_01"

Use additional --input options to compare multiple independent captures.
The output directory must be absent or empty, avoiding accidental overwrites.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import re
import sys
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

try:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as exc:
    raise SystemExit("STOP: Install packages using python -m pip install numpy matplotlib") from exc

ADC_BITS = 14
ADC_MIN = -(1 << (ADC_BITS - 1))
ADC_MAX = (1 << (ADC_BITS - 1)) - 1
ADC_SPAN = 1 << ADC_BITS
CH_NAMES = ("CH0", "CH1", "CH2", "CH3")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for block in iter(lambda: fp.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def csv_text(path: Path) -> str:
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            choices = [s for s in z.namelist() if s.rsplit("/", 1)[-1].lower() == "waveform.csv"]
            if len(choices) != 1:
                raise ValueError(f"Expected exactly one waveform.csv in .ila, found {len(choices)}")
            raw = z.read(choices[0])
        return raw.decode("utf-8-sig")
    return path.read_text(encoding="utf-8-sig")


def find_one(columns: list[str], predicate, label: str) -> int:
    matches = [i for i, name in enumerate(columns) if predicate(name.lower())]
    if len(matches) != 1:
        raise ValueError(f"Could not unambiguously select {label}. Matches={matches}; columns={columns}")
    return matches[0]


def column_map(headers: list[str]) -> dict:
    return {
        "idx": find_one(headers, lambda s: s.strip() == "sample in buffer", "sample index"),
        "counter": find_one(headers, lambda s: "counter12[15:0]" in s, "16-bit counter"),
        "status": find_one(headers, lambda s: "single_ila_status[3:0]" in s, "FIFO status"),
        "CH0": find_one(headers, lambda s: "adc_twos_ch0_delayed[13:0]" in s, "CH0"),
        "CH1": find_one(headers, lambda s: "adc_twos_ch1_delayed[13:0]" in s, "CH1"),
        "CH2": find_one(headers, lambda s: re.search(r"/fifo_dout_1\[13:0\]$", s) is not None or re.search(r"/fifo_dout\[13:0\]$", s) is not None, "CH2"),
        "CH3": find_one(headers, lambda s: re.search(r"/fifo_dout\[27:14\]$", s) is not None, "CH3"),
    }


def read_signed_14(token: str, radix: str) -> int:
    t = token.strip()
    if not t:
        raise ValueError("Empty ADC sample")
    radix = radix.upper()
    if "HEX" in radix or t.lower().startswith("0x") or re.search(r"[a-fA-F]", t):
        u = int(t, 16)
        if not 0 <= u < ADC_SPAN:
            raise ValueError(f"14-bit hex code out of range: {t}")
        return u - ADC_SPAN if u >= 8192 else u
    v = int(t, 10)
    # 'Radix - UNSIGNED' is common in .ila; reconstruct signed 14-bit codes.
    if v > ADC_MAX and v < ADC_SPAN:
        v -= ADC_SPAN
    if not ADC_MIN <= v <= ADC_MAX:
        raise ValueError(f"Out-of-range 14-bit ADC code: {t} => {v}")
    return v


def read_capture(path: Path):
    rows = list(csv.reader(io.StringIO(csv_text(path))))
    if len(rows) < 3:
        raise ValueError("CSV has insufficient lines")
    headers = [s.strip() for s in rows[0]]
    c = column_map(headers)
    if rows[1] and rows[1][0].lower().startswith("radix"):
        radixes = [s.strip() for s in rows[1]]
        data = rows[2:]
    else:
        radixes = ["SIGNED"] * len(headers)
        data = rows[1:]
    data = [r for r in data if r and any(s.strip() for s in r)]
    if not data:
        raise ValueError("No capture records")
    if any(len(r) != len(headers) for r in data):
        raise ValueError("A row has a different number of columns than CSV header")
    samples = np.array([[read_signed_14(row[c[ch]], radixes[c[ch]]) for ch in CH_NAMES]
                        for row in data], dtype=np.float64)
    idx = np.array([int(row[c["idx"]], 10) for row in data], dtype=np.int64)
    counter = np.array([int(row[c["counter"]], 16) for row in data], dtype=np.int64)
    status = np.array([int(row[c["status"]], 16) for row in data], dtype=np.int64)
    return samples, idx, counter, status, headers


def fit_at(y: np.ndarray, fs: float, f: float):
    t = np.arange(y.size, dtype=np.float64) / fs
    ang = (2.0 * math.pi * f) * t
    X = np.column_stack((np.sin(ang), np.cos(ang), np.ones_like(t)))
    coeffs = np.linalg.lstsq(X, y, rcond=None)[0]
    pred = X @ coeffs
    resid = y - pred
    mse = float(np.mean(resid ** 2))
    amp = float(math.hypot(coeffs[0], coeffs[1]))
    phase = float(math.atan2(coeffs[1], coeffs[0]))
    return mse, pred, amp, float(coeffs[2]), phase


def best_fit(y: np.ndarray, fs: float, nominal_f: float, span_hz: float):
    lo = max(1.0, nominal_f - span_hz)
    hi = min(fs * 0.499, nominal_f + span_hz)
    if lo >= hi:
        raise ValueError("Invalid nominal tone/span/ADC sample rate")
    grid = np.linspace(lo, hi, 161)
    errors = [fit_at(y, fs, float(f))[0] for f in grid]
    k = int(np.argmin(errors))
    a = float(grid[max(0, k - 1)])
    b = float(grid[min(len(grid) - 1, k + 1)])
    # Refine locally using golden section; no SciPy dependency.
    g = (math.sqrt(5.0) - 1.0) / 2.0
    c = b - g * (b - a)
    d = a + g * (b - a)
    fc, fd = fit_at(y, fs, c)[0], fit_at(y, fs, d)[0]
    for _ in range(42):
        if fc < fd:
            b, d, fd = d, c, fc
            c = b - g * (b - a)
            fc = fit_at(y, fs, c)[0]
        else:
            a, c, fc = c, d, fd
            d = a + g * (b - a)
            fd = fit_at(y, fs, d)[0]
    f = (a + b) / 2.0
    mse, pred, amp, offset, phase = fit_at(y, fs, f)
    sst = float(np.mean((y - y.mean()) ** 2))
    r2 = 1.0 - mse / sst if sst > 0 else float("nan")
    rmse = math.sqrt(mse)
    fit_ratio_db = 20 * math.log10(amp / (math.sqrt(2) * rmse)) if amp > 0 and rmse > 0 else None
    return {
        "fit_frequency_hz": f,
        "fit_amplitude_peak_codes": amp,
        "amplitude_dbfs_nominal": 20 * math.log10(amp / 8192.0) if amp > 0 else None,
        "fit_dc_offset_codes": offset,
        "fit_phase_rad": phase,
        "r_squared": r2,
        "residual_rms_codes": rmse,
        "sine_fit_to_residual_db_NOT_SNR": fit_ratio_db,
        "sample_min_codes": int(y.min()),
        "sample_max_codes": int(y.max()),
        "sample_mean_codes": float(y.mean()),
        "sample_std_codes": float(np.std(y)),
    }, pred


def angle_wrap(a: float) -> float:
    return (a + math.pi) % (2 * math.pi) - math.pi


def render_plots(samples, predicted, fits, fs, run_dir):
    n = min(samples.shape[0], 500)
    t_us = np.arange(n, dtype=np.float64) / fs * 1e6
    for i, ch in enumerate(CH_NAMES):
        fig, ax = plt.subplots(figsize=(11, 4.1))
        ax.plot(t_us, samples[:n, i], label="Measured ADC codes", lw=1.25)
        ax.plot(t_us, predicted[:n, i], label="Best-fit sine model", lw=1.8, ls="--")
        ax.set(xlabel="Time (us)", ylabel="14-bit signed ADC codes",
               title=f"{ch}: measured vs fitted sine | R²={fits[ch]['r_squared']:.6f}")
        ax.grid(alpha=.25)
        ax.legend()
        fig.tight_layout()
        fig.savefig(run_dir / f"{ch.lower()}_measured_vs_fit.png", dpi=160)
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(11, 4.5))
    for i, ch in enumerate(CH_NAMES):
        ax.plot(t_us, (samples[:n, i] - predicted[:n, i]), label=ch, lw=0.85)
    ax.set(xlabel="Time (us)", ylabel="Measured - sine fit (ADC codes)",
           title="Four-channel residual waveform — not pure ADC noise")
    ax.grid(alpha=.25)
    ax.legend(ncol=4)
    fig.tight_layout()
    fig.savefig(run_dir / "four_channel_fit_residuals.png", dpi=160)
    plt.close(fig)

    # Normalizing each channel makes the relative phase/equality easy to inspect.
    fig, ax = plt.subplots(figsize=(11, 4.5))
    for i, ch in enumerate(CH_NAMES):
        a = fits[ch]["fit_amplitude_peak_codes"]
        if a > 0:
            ax.plot(t_us, (samples[:n, i] - fits[ch]["fit_dc_offset_codes"]) / a,
                    label=ch, lw=1.2)
    ax.set(xlabel="Time (us)", ylabel="(ADC code - offset) / fitted amplitude",
           title="Normalized CH0–CH3 waveforms (apparent phase only)")
    ax.grid(alpha=.25)
    ax.legend(ncol=4)
    fig.tight_layout()
    fig.savefig(run_dir / "four_channel_normalized_overlay.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(11, 4.5))
    window = np.hanning(samples.shape[0]); wsum = window.sum()
    f_hz = np.fft.rfftfreq(samples.shape[0], d=1.0 / fs)
    for i, ch in enumerate(CH_NAMES):
        y = samples[:, i] - np.mean(samples[:, i])
        spectrum = np.abs(np.fft.rfft(y * window)) * 2.0 / wsum
        dbfs = 20.0 * np.log10(np.maximum(spectrum / 8192.0, 1e-12))
        ax.plot(f_hz / 1e6, dbfs, label=ch, lw=0.9)
    ax.set(xlabel="Frequency (MHz)", ylabel="Windowed FFT bin amplitude (dBFS approx)",
           title="Diagnostic spectrum (Hann window; not calibrated IEEE SNR/SFDR)")
    ax.set_ylim(bottom=-125)
    ax.grid(alpha=.25)
    ax.legend(ncol=4)
    fig.tight_layout()
    fig.savefig(run_dir / "four_channel_diagnostic_fft.png", dpi=160)
    plt.close(fig)


def save_csv(path, rows):
    if not rows:
        return
    fields = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def analyze(path, outdir, args):
    samples, idx, counter, status, headers = read_capture(path)
    n = len(samples)
    idx_bad = int(np.count_nonzero(np.diff(idx) != 1))
    idx_first_zero = bool(idx[0] == 0)
    counter_bad = int(np.count_nonzero(((np.diff(counter) % 65536) != 1)))
    status_counts = dict(sorted((f"0x{int(k):X}", int(v))
                                for k, v in Counter(status.tolist()).items()))
    bad_status = int(np.count_nonzero(status != args.expected_status))
    clipping = [int(np.count_nonzero((samples[:, i] == ADC_MIN) | (samples[:, i] == ADC_MAX)))
                for i in range(4)]
    flags = {
        "sample_count_expected": n == args.expected_samples,
        "sample_index_contiguous_from_zero": (idx_bad == 0 and idx_first_zero),
        "counter_contiguous_mod_65536": counter_bad == 0,
        "status_all_expected": bad_status == 0,
        "no_endpoint_clipping": all(x == 0 for x in clipping),
    }

    fits, predicted = {}, np.zeros_like(samples)
    for i, ch in enumerate(CH_NAMES):
        fit, pred = best_fit(samples[:, i], args.fs_hz, args.tone_hz, args.search_span_hz)
        fit["channel"] = ch
        fit["endpoint_clipping_count"] = clipping[i]
        fit["frequency_error_percent_vs_nominal"] = 100.0 * (fit["fit_frequency_hz"] - args.tone_hz) / args.tone_hz
        fit["r2_screen_pass"] = bool(fit["r_squared"] >= args.min_r2)
        fit["amplitude_screen_pass"] = bool(fit["fit_amplitude_peak_codes"] >= args.min_amplitude_codes)
        fits[ch] = fit
        predicted[:, i] = pred

    # Phase comparison MUST use the same fitted frequency for all channels.
    shared_f = fits["CH0"]["fit_frequency_hz"]
    phase_shared = [fit_at(samples[:, i], args.fs_hz, shared_f)[4] for i in range(4)]
    for i, ch in enumerate(CH_NAMES):
        lag_rad = angle_wrap(phase_shared[0] - phase_shared[i])
        fits[ch]["apparent_lag_vs_ch0_samples_MODULO_PERIOD"] = lag_rad * args.fs_hz / (2 * math.pi * shared_f)
        fits[ch]["apparent_lag_vs_ch0_ns_MODULO_PERIOD"] = lag_rad * 1e9 / (2 * math.pi * shared_f)
    flags["all_channels_sine_screen_pass"] = all(
        f["r2_screen_pass"] and f["amplitude_screen_pass"] for f in fits.values())
    core_pass = all(flags.values())

    report = {
        "scope": "Experimental ADC-only 4-channel single-ILA capture; no VDIF, DMA, or digital quadrature mixer",
        "input_file": str(path.resolve()),
        "input_sha256": sha256(path),
        "utc_analysis_time": datetime.now(timezone.utc).isoformat(),
        "nominal_fs_hz": args.fs_hz,
        "nominal_generator_frequency_hz": args.tone_hz,
        "generator_power_dbm_USER_REPORTED": args.generator_dbm,
        "firmware_USER_REPORTED": args.firmware,
        "analog_frontend_input_voltage_UNMEASURED": True,
        "sample_count": n,
        "counter_start_hex": f"0x{counter[0]:04X}",
        "counter_end_hex": f"0x{counter[-1]:04X}",
        "counter_transition_errors": counter_bad,
        "sample_index_discontinuities": idx_bad,
        "fifo_status_histogram_hex": status_counts,
        "unexpected_status_count": bad_status,
        "functional_screening_flags": flags,
        "functional_capture_screen_pass": core_pass,
        "engineering_screening_thresholds_NOT_IEEE": {
            "minimum_r_squared": args.min_r2,
            "minimum_sine_amplitude_peak_codes": args.min_amplitude_codes,
            "expected_status_hex": f"0x{args.expected_status:X}",
        },
        "limitations": [
            "Sine-fit residual includes generator noise/distortion, harmonics, ADC and frontend errors; it is NOT ADC-only SNR/SINAD/ENOB.",
            "No absolute voltage calibration: dBm refers to generator setting and may differ from power at ADC input.",
            "No physical bit-pattern checker or IDELAY tap-margin sweep; individual bit error rate remains unqualified.",
            "CH0/CH1 are delayed 8 ADC0 clocks; CH2/CH3 are transferred through async FIFO.",
            "Phase differences are periodic-sine apparent lag modulo a period, not simultaneous physical sampling or calibrated channel skew.",
            "Nominal 125 MHz sample rate is assumed, not independently metrologically measured.",
            "0x7 shows no REPORTED FIFO drop IN THIS CAPTURE, not indefinite gaplessness.",
            "This is a functional engineering screening result, NOT IEEE 1241 certification or final sign-off.",
        ],
        "channels": fits,
    }
    outdir.mkdir(parents=True, exist_ok=False)
    with (outdir / "analysis.json").open("w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, allow_nan=False)
    save_csv(outdir / "channel_metrics.csv", [fits[ch] for ch in CH_NAMES])
    # Preserve every measured sample alongside its fitted estimate and residual.
    with (outdir / "samples_measured_fitted_residual.csv").open("w", newline="", encoding="utf-8") as fp:
        wr = csv.writer(fp)
        wr.writerow(["sample_index", "counter_hex", "status_hex"] +
                    [f"{ch}_{suffix}" for ch in CH_NAMES for suffix in
                     ("measured_signed_codes", "sine_fitted_codes", "residual_codes")])
        for j in range(n):
            fields = [int(idx[j]), f"0x{int(counter[j]):04X}", f"0x{int(status[j]):X}"]
            for i in range(4):
                fields += [int(samples[j, i]), round(float(predicted[j, i]), 6),
                           round(float(samples[j, i] - predicted[j, i]), 6)]
            wr.writerow(fields)
    render_plots(samples, predicted, fits, args.fs_hz, outdir)
    with (outdir / "README_RESULTS.txt").open("w", encoding="utf-8") as fh:
        fh.write(f"INPUT: {path.resolve()}\nSHA256: {report['input_sha256']}\n"
                 f"FUNCTIONAL ENGINEERING SCREEN: {'PASS' if core_pass else 'REVIEW NEEDED'}\n"
                 "NOT IEEE 1241 CERTIFIED; see analysis.json limitations.\n"
                 "Phase values cannot establish absolute simultaneity.\n")
    print("\nCAPTURE:", path)
    print(f"N={n}, counter errors={counter_bad}, index errors={idx_bad}, status={status_counts}")
    print(f"{'Channel':<8}{'Frequency (MHz)':>18}{'Peak codes':>14}{'DC codes':>14}{'R2':>13}{'Resid RMS':>13}{'Lag (samples)':>16}")
    for ch in CH_NAMES:
        d = fits[ch]
        print(f"{ch:<8}{d['fit_frequency_hz']/1e6:>18.6f}{d['fit_amplitude_peak_codes']:>14.2f}"
              f"{d['fit_dc_offset_codes']:>14.2f}{d['r_squared']:>13.6f}"
              f"{d['residual_rms_codes']:>13.2f}{d['apparent_lag_vs_ch0_samples_MODULO_PERIOD']:>16.3f}")
    print("FUNCTIONAL_ADC_CAPTURE_SCREEN:", "PASS" if core_pass else "REVIEW_NEEDED")
    print("NOT_IEEE_1241_CERTIFIED: YES")
    print("OUTPUT:", outdir)
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", type=Path, action="append", required=True,
                    help="Input .ila or exported .csv. Repeat for multiple independent captures.")
    ap.add_argument("--out", type=Path, required=True,
                    help="New or empty output folder; this program never overwrites previous results")
    ap.add_argument("--tone-hz", type=float, default=5_000_000, help="Nominal generator sine frequency")
    ap.add_argument("--fs-hz", type=float, default=125_000_000, help="Assumed ADC sampling frequency")
    ap.add_argument("--generator-dbm", type=float, default=None,
                    help="Record generator setting only; not a measured ADC-input voltage")
    ap.add_argument("--firmware", type=str, default="align8_step273 (user-reported)")
    ap.add_argument("--expected-status", type=lambda s: int(s, 0), default=0x7)
    ap.add_argument("--expected-samples", type=int, default=4096)
    ap.add_argument("--search-span-hz", type=float, default=20_000,
                    help="Sine frequency search around nominal (default ±20000 Hz)")
    ap.add_argument("--min-r2", type=float, default=0.99,
                    help="Engineering visual sine-screen threshold only")
    ap.add_argument("--min-amplitude-codes", type=float, default=20,
                    help="Engineering visual signal-present threshold only")
    args = ap.parse_args()
    if args.tone_hz <= 0 or args.fs_hz <= 0 or args.tone_hz >= args.fs_hz / 2 or args.search_span_hz <= 0:
        ap.error("Require 0 < tone-hz < fs-hz/2, positive search span")
    if len(args.input) != len({str(p.resolve()).casefold() for p in args.input}):
        ap.error("Duplicate input paths are not permitted")
    for p in args.input:
        if not p.is_file():
            ap.error(f"Input file missing: {p}")
    if args.out.exists() and any(args.out.iterdir()):
        ap.error(f"STOP: Output directory already has files, refusing to overwrite: {args.out}")
    args.out.mkdir(parents=True, exist_ok=True)
    all_rows = []
    any_fail = False
    for i, path in enumerate(args.input, 1):
        outdir = args.out / f"capture_{i:02d}"
        rep = analyze(path, outdir, args)
        any_fail |= not rep["functional_capture_screen_pass"]
        for ch in CH_NAMES:
            all_rows.append({"capture": i, "source_filename": path.name, "source_sha256": rep["input_sha256"],
                             "screen_pass": rep["functional_capture_screen_pass"], **rep["channels"][ch]})
    save_csv(args.out / "all_capture_comparison.csv", all_rows)
    print("\nALL INPUTS processed. Multi-capture comparison: ", args.out / "all_capture_comparison.csv")
    if any_fail:
        print("ATTENTION: At least one functional screening check needs review.")
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as e:
        print(f"STOP: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(2)
