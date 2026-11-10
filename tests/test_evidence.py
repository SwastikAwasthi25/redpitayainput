"""Tests against the actual raw Vivado ILA captures, not synthetic waveforms."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestAdcEvidence(unittest.TestCase):
    def test_real_csv_analysis(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = subprocess.run([sys.executable, str(ROOT/'scripts/analyze_capture.py'),
               '--old', str(ROOT/'evidence/data/original_5mhz_ch01.csv'),
               '--new', str(ROOT/'evidence/data/corrected_5mhz_ch01.csv'),
               '--output', tmp], capture_output=True, text=True, check=True)
            obj = json.loads((Path(tmp)/'metrics.json').read_text())
            self.assertEqual(obj['original']['sample_count'], 4096)
            self.assertEqual(obj['corrected']['sample_count'], 4096)
            self.assertTrue(obj['original']['counter_continuous'])
            self.assertTrue(obj['corrected']['counter_continuous'])
            self.assertEqual(obj['original']['status_values_hex'], ['0xF'])
            self.assertEqual(obj['corrected']['status_values_hex'], ['0xF'])
            self.assertLess(obj['original']['r2'], .20)
            self.assertGreater(obj['corrected']['r2'], .9999)
            self.assertLess(abs(obj['corrected']['fitted_frequency_hz']-5_000_000), 150)
            self.assertTrue(obj['corrected']['raw_signed_xor_1fff'])
            self.assertFalse(obj['hardware_signoff'])

if __name__ == '__main__':
    unittest.main()
