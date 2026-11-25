"""Unit tests for portable parsing and optional integration regression.

Run "python -m unittest discover -v" in this directory.
With iladata(1).ila placed alongside the scripts, all hardware integration
tests run; without it those tests are skipped, not failed.
"""
from pathlib import Path
import hashlib
import math
import unittest
import numpy as np
import adc_4ch_validate as adc

HERE = Path(__file__).resolve().parent
CAPTURE = HERE / "iladata(1).ila"
EXPECTED_SHA256 = "bd594d609e60538df9a893a858cec5b3ad821329c12c77e81b2c72c6615502c1"

class UnitTests(unittest.TestCase):
    def test_signed_radix(self):
        self.assertEqual(adc.read_signed_14("16234", "UNSIGNED"), -150)
        self.assertEqual(adc.read_signed_14("-150", "SIGNED"), -150)
        self.assertEqual(adc.read_signed_14("3f6a", "HEX"), -150)
        self.assertEqual(adc.read_signed_14("8191", "UNSIGNED"), 8191)
        self.assertEqual(adc.read_signed_14("8192", "UNSIGNED"), -8192)

    def test_model_fit_on_synthetic_vector(self):
        fs, f = 125_000_000, 5_000_000
        n = np.arange(4096)
        y = 180 * np.sin(2*np.pi*f*n/fs+0.3)-40
        fit, predicted = adc.best_fit(y, fs, f, 20_000)
        self.assertLess(abs(fit["fit_frequency_hz"]-f), 1)
        self.assertLess(abs(fit["fit_amplitude_peak_codes"]-180), 0.01)
        self.assertGreater(fit["r_squared"], 0.9999999)

    def test_sine_phase_wrap(self):
        self.assertAlmostEqual(adc.angle_wrap(2*math.pi), 0, places=10)

@unittest.skipUnless(CAPTURE.is_file(), "Original .ila archive retained separately; copy alongside scripts for integration verification")
class HardwareCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data, cls.idx, cls.counter, cls.status, _ = adc.read_capture(CAPTURE)

    def test_hash(self):
        self.assertEqual(adc.sha256(CAPTURE), EXPECTED_SHA256)

    def test_shape_and_indices(self):
        self.assertEqual(self.data.shape, (4096, 4))
        np.testing.assert_array_equal(self.idx, np.arange(4096))

    def test_counter_and_fifo_status(self):
        self.assertTrue(np.all((np.diff(self.counter) % 65536) == 1))
        self.assertEqual(set(self.status.tolist()), {7})

    def test_known_first_codes(self):
        np.testing.assert_array_equal(self.data[0], [29, 70, 29, 14])

    def test_four_channels_fit(self):
        for i in range(4):
            fit, _ = adc.best_fit(self.data[:, i], 125_000_000, 5_000_000, 20_000)
            self.assertGreater(fit["r_squared"], 0.998)
            self.assertLess(abs(fit["fit_frequency_hz"]-5e6), 200)

if __name__ == "__main__":
    unittest.main(verbosity=2)
