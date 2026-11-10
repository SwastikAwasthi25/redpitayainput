#!/usr/bin/env python3
"""Best-effort review for accidental sensitive text before a GitHub push.

It cannot certify third-party licensing; always review files manually.
"""
from __future__ import annotations
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
paths = [root/'fpga/source_snapshot',root/'fpga/external_constraints']
files = []
for base in paths:
    if base.exists():
        files += [f for f in base.rglob('*') if f.is_file() and f.stat().st_size < 4_000_000]
patterns = {
    'private_key': re.compile(r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'),
    'github_token': re.compile(r'gh[pousr]_[A-Za-z0-9_]{25,}'),
    'possible_hardcoded_secret': re.compile(r'(?i)\b(?:password|api[_-]?key|secret|token)\b\s*[:=]\s*["\x27][^"\x27\s]{10,}["\x27]'),
    'absolute_windows_path': re.compile(r'(?i)[A-Z]:[\\/](?:Users|rp-adc-ila|projects|source)[\\/]'),
}
issues = []
for f in files:
    try: text = f.read_text(encoding='utf-8-sig')
    except (UnicodeError, OSError): continue
    for name, rx in patterns.items():
        if rx.search(text): issues.append((f.relative_to(root).as_posix(),name))
if not files:
    print('PUBLICATION_AUDIT: SOURCE_NOT_EXPORTED')
else:
    print('PUBLICATION_AUDIT: scanned',len(files),'text-like files')
for path,issue in issues:
    print('REVIEW:',issue,'in',path)
print('MANUAL_REVIEW_REQUIRED: Vendor IP redistribution, institution approval, .xpr paths, and board wiring.')
raise SystemExit(1 if any(name in ('private_key','github_token','possible_hardcoded_secret') for _,name in issues) else 0)
