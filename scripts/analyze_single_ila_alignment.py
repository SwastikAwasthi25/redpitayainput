#!/usr/bin/env python3
"""Analyze signed 14-bit 4-channel Vivado single-ILA CSV exports.

Usage:
    python -m pip install numpy
    python scripts/analyze_single_ila_alignment.py \
        adc_1mhz_before_alignment_4096.csv \
        adc_1mhz_after_8cycle_alignment_4096.csv --frequency-mhz 1

The phase difference is modulo one sine period. This is NOT an absolute
FIFO-latency or clock-domain-simultaneity measurement.
"""
import argparse
import csv
import math
from pathlib import Path

import numpy as np

FIELDS = [
    "ch0_signed14_adc_codes",
    "ch1_signed14_adc_codes",
    "ch2_signed14_adc_codes_via_fifo",
    "ch3_signed14_adc_codes_via_fifo",
]

def load(path):
    with open(path, newline="", encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))
    if not rows or not all(k in rows[0] for k in FIELDS):
        raise ValueError(f"{path}: expected 4 signed ADC-code columns")
    codes = np.asarray([[int(row[k]) for k in FIELDS] for row in rows], dtype=float)
    if np.any(codes < -8192) or np.any(codes > 8191):
        raise ValueError(f"{path}: values outside 14-bit signed ADC range")
    if not all(int(r["sample_index"]) == i for i, r in enumerate(rows)):
        raise ValueError(f"{path}: sample indices are discontinuous")
    counts = [int(r["adc_counter_hex"], 16) for r in rows]
    bad = sum((b - a) % 65536 != 1 for a, b in zip(counts, counts[1:]))
    status = sorted(set(r["ila_status_hex"].upper() for r in rows))
    return codes, bad, status

def summary(path, sample_hz, signal_hz):
    data, counter_gaps, status = load(path)
    samples = np.arange(len(data), dtype=float)
    omega = 2.0 * np.pi * signal_hz / sample_hz
    regressors = np.stack([np.sin(omega * samples),
                            np.cos(omega * samples),
                            np.ones_like(samples)], axis=1)
    fitted = np.linalg.lstsq(regressors, data, rcond=None)[0]
    phase = np.arctan2(fitted[1, :], fitted[0, :])
    # Positive lag means this channel appears later than CH0.
    lag = (phase[0] - phase + np.pi) % (2 * np.pi) - np.pi
    lag_samples = lag / omega
    recon = regressors @ fitted
    r2 = 1 - np.sum((data - recon)**2, axis=0) / np.sum(
        (data - np.mean(data, axis=0))**2, axis=0)
    return data, lag_samples, r2, counter_gaps, status

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--sample-mhz", type=float, default=125)
    parser.add_argument("--frequency-mhz", type=float, default=1)
    args = parser.parse_args()
    if args.sample_mhz <= 0 or args.frequency_mhz <= 0:
        parser.error("sample-mhz and frequency-mhz must be positive")
    results = [summary(path, args.sample_mhz * 1e6,
                       args.frequency_mhz * 1e6)
               for path in (args.before, args.after)]
    for label, path, result in zip(("BEFORE", "AFTER"),
                                   (args.before, args.after), results):
        data, lags, r2, gaps, status = result
        print(f"{label}: {path}, n={len(data)}, "
              f"counter_discontinuities={gaps}, status={status}")
        for ch in range(4):
            print(f"  CH{ch}: min={int(data[:, ch].min()):+d}, "
                  f"max={int(data[:, ch].max()):+d}, "
                  f"lag_samples={lags[ch]:+.3f}, "
                  f"lag_ns={lags[ch] * 1000 / args.sample_mhz:+.2f}, "
                  f"R2={r2[ch]:.6f}")
    print("NOTE: Apparent sinusoidal phase, not absolute FIFO latency.")

if __name__ == "__main__":
    main()
