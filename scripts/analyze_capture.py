#!/usr/bin/env python3
"""Reproducible comparison of Vivado ILA ADC captures.

Measurements describe these captures, not a calibrated ADC performance specification.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

import numpy as np
from scipy.optimize import minimize_scalar


def load_capture(path: Path) -> dict:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.reader(fh)
        header = next(reader)
        radix = next(reader)
        rows = list(reader)
    if not rows or len(header) < 7 or not header[0].startswith("Sample in Buffer"):
        raise ValueError(f"Not a Vivado ILA CSV capture: {path}")
    if len(radix) != len(header) or any(len(row) != len(header) for row in rows):
        raise ValueError(f"Malformed CSV columns: {path}")
    if len(rows) != 4096:
        raise ValueError(f"Expected 4096 ILA samples, got {len(rows)}: {path}")
    cols = {name: [row[i] for row in rows] for i, name in enumerate(header)}
    samples = np.asarray([int(v) for v in cols["Sample in Buffer"]], dtype=np.int64)
    if not np.array_equal(samples, np.arange(4096)):
        raise ValueError(f"Non-contiguous sample index: {path}")

    def signal(label: str, ch: int) -> np.ndarray:
        key = next((k for k in cols if f"/{label}[{ch}]_" in k), None)
        if key is None:
            raise ValueError(f"No {label}[{ch}] in {path}")
        return np.asarray([int(v, 10) for v in cols[key]], dtype=np.int64)

    counter_key = next((k for k in cols if "/counter12[" in k), None)
    status_key = next((k for k in cols if "/status12_sync[" in k), None)
    if counter_key is None or status_key is None:
        raise ValueError("Expected ILA1 counter12 and status12_sync columns")
    counters = np.asarray([int(v, 16) for v in cols[counter_key]], dtype=np.int64)
    counter_continuous = bool(np.all((np.diff(counters) % 65536) == 1))
    status_values = sorted({int(v, 16) for v in cols[status_key]})
    return {"path": path, "samples": 4096, "counter_continuous": counter_continuous,
            "status_values_hex": [f"0x{v:X}" for v in status_values],
            "raw0": signal("adc_raw", 0), "raw1": signal("adc_raw", 1),
            "signed0": signal("adc_signed", 0), "signed1": signal("adc_signed", 1)}


def fit_at_frequency(y: np.ndarray, fs_hz: float, freq_hz: float):
    t = np.arange(len(y), dtype=float) / fs_hz
    basis = np.column_stack((np.sin(2*np.pi*freq_hz*t),
                             np.cos(2*np.pi*freq_hz*t), np.ones(len(y))))
    coefficients, *_ = np.linalg.lstsq(basis, y, rcond=None)
    pred = basis @ coefficients
    rms = float(np.sqrt(np.mean((y-pred)**2)))
    sst = float(np.sum((y - np.mean(y)) ** 2))
    r2 = (1.0 - float(np.sum((y-pred)**2))/sst) if sst > 0 else float("nan")
    amplitude = float(np.hypot(coefficients[0], coefficients[1]))
    return {"r2": r2, "residual_rms_codes": rms,
            "amplitude_peak_codes": amplitude, "dc_offset_codes": float(coefficients[2])}, pred


def sine_fit(y: np.ndarray, fs_hz: float, expected_hz: float):
    # Coarse scan around the known laboratory generator setting to avoid a local minimum.
    step_hz = 250.0
    grid = np.arange(expected_hz-20000, expected_hz+20000+step_hz, step_hz)
    scores = [fit_at_frequency(y, fs_hz, float(f))[0]["r2"] for f in grid]
    k = int(np.argmax(scores))
    left = float(grid[max(0, k-1)])
    right = float(grid[min(len(grid)-1, k+1)])
    opt = minimize_scalar(lambda f: -fit_at_frequency(y, fs_hz, f)[0]["r2"],
                          bounds=(left, right), method="bounded",
                          options={"xatol": 0.01})
    details, pred = fit_at_frequency(y, fs_hz, float(opt.x))
    return {"fitted_frequency_hz": round(float(opt.x), 3), **details}, pred


def dominant_fft(y: np.ndarray, fs_hz: float) -> float:
    n = len(y)
    fft = abs(np.fft.rfft((y - y.mean()) * np.hanning(n)))
    idx = int(np.argmax(fft[1:]) + 1)
    return round(idx * fs_hz / n, 2)  # frequency-bin resolution: fs/N


def raw_signed_relation(record: dict, ch: int) -> bool:
    # Empirical relationship in these datasets. Not assumed to be the ADC datasheet format.
    raw = record[f"raw{ch}"] & 0x3FFF
    signed = record[f"signed{ch}"] & 0x3FFF
    return bool(np.all((raw ^ 0x1FFF) == signed))


def get_results(path: Path, ch: int, fs_hz: float, tone_hz: float):
    capture = load_capture(path)
    y = capture[f"signed{ch}"].astype(float)
    fit, pred = sine_fit(y, fs_hz, tone_hz)
    return ({"source_csv": path.name, "active_channel": ch,
             "sample_count": capture["samples"],
             "counter_continuous": capture["counter_continuous"],
             "status_values_hex": capture["status_values_hex"],
             "raw_signed_xor_1fff": raw_signed_relation(capture, ch),
             "dominant_fft_bin_hz": dominant_fft(y, fs_hz),
             "signed_min_codes": int(y.min()), "signed_max_codes": int(y.max()),
             **fit}, y, pred)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--fs", type=float, default=125_000_000,
                        help="Assumed sampling clock in Hz; verify in Vivado")
    parser.add_argument("--tone", type=float, default=5_000_000,
                        help="Known signal generator sine frequency in Hz")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    a, old, oldfit = get_results(args.old, 1, args.fs, args.tone)
    b, new, newfit = get_results(args.new, 0, args.fs, args.tone)
    result = {"measurement_scope": "single 4096-sample ILA1 capture per firmware version",
              "assumed_sample_rate_hz": args.fs, "signal_generator_nominal_hz": args.tone,
              "comparison_note": "Old signal appears on CH1; corrected signal on CH0. Physical SMA channel was not independently confirmed. Two different captures; not a controlled same-channel A/B test.",
              "hardware_signoff": False,
              "original": a, "corrected": b}
    (args.output / "metrics.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        t_us = np.arange(150) / args.fs * 1e6
        fig, ax = plt.subplots(figsize=(11, 4.8))
        ax.plot(t_us, old[:150], label="Original CH1 signed (distorted)", lw=1.3)
        ax.plot(t_us, new[:150], label="Corrected CH0 signed (sine)", lw=1.7)
        ax.set(xlabel="Time (microseconds)", ylabel="ADC output code",
               title="5 MHz input: ILA capture before vs after DDR correction")
        ax.grid(alpha=.25)
        ax.legend()
        fig.tight_layout()
        fig.savefig(args.output / "before_after.png", dpi=175)
        plt.close(fig)
    except ImportError:
        print("matplotlib unavailable; statistics and JSON still exported")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
