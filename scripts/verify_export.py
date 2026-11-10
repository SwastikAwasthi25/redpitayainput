#!/usr/bin/env python3
"""Verify byte-accurate files copied from the actual Windows Vivado sandbox."""
from __future__ import annotations
import argparse
import csv
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'fpga' / 'provenance_manifest.csv'


def verify(require_source: bool=False):
    if not MANIFEST.exists():
        print('SOURCE_EXPORT: NOT_PRESENT — starter kit only; run scripts/collect_from_windows.ps1')
        return 1 if require_source else 0
    rows = list(csv.DictReader(MANIFEST.open(encoding='utf-8-sig', newline='')))
    if not rows:
        raise RuntimeError('Empty source manifest')
    root_resolved = ROOT.resolve()
    for row in rows:
        rel = Path(row['repo_relative_path'])
        if rel.is_absolute() or '..' in rel.parts:
            raise RuntimeError(f'Unsafe manifest path: {rel}')
        actual = (ROOT / rel).resolve()
        if not actual.is_relative_to(root_resolved):
            raise RuntimeError(f'Path escapes the repository: {rel}')
        if not actual.is_file():
            raise RuntimeError(f'Missing exported source: {rel}')
        b = actual.read_bytes()
        if len(b) != int(row['size_bytes']) or hashlib.sha256(b).hexdigest().lower() != row['sha256'].lower():
            raise RuntimeError(f'File mismatch: {rel}')
    source = ROOT/'fpga/source_snapshot/adc_clock_sandbox.srcs/sources_1/imports/rtl/adc_ddr_unpack.sv'
    if not source.exists():
        raise RuntimeError('Real adc_ddr_unpack.sv missing from source snapshot')
    code = source.read_text(encoding='utf-8-sig')
    for p in ['.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")', '.Q1(adc_raw[ch][2*bit_idx])', '.Q2(adc_raw[ch][2*bit_idx+1])']:
        if p not in code:
            raise RuntimeError(f'Wrong IDDR source content: {p}')
    print(f'SOURCE_EXPORT: VERIFIED ({len(rows)} hash-matched files; corrected DDR source present)')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-source', action='store_true')
    args = parser.parse_args()
    try:
        raise SystemExit(verify(args.require_source))
    except (RuntimeError, OSError, ValueError) as exc:
        print('SOURCE_EXPORT: FAIL:', exc)
        raise SystemExit(1)
