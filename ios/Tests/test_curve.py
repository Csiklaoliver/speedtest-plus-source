from __future__ import annotations

import math
import unittest


PROGRESS = [0.00, 0.09, 0.18, 0.27, 0.36, 0.45, 0.55, 0.64, 0.73, 0.82, 0.91, 1.00]
PERMILLE = [40, 160, 380, 620, 800, 920, 1010, 980, 1030, 1000, 1010, 1000]


def rounded(value: float) -> float:
    return math.floor(value * 10.0 + 0.5) / 10.0


def samples(final: float):
    return [(progress, final if index == 11 else rounded(final * PERMILLE[index] / 1000.0)) for index, progress in enumerate(PROGRESS)]


class CurveContractTests(unittest.TestCase):
    def test_has_twelve_samples(self):
        self.assertEqual(12, len(samples(274.0)))

    def test_final_is_exact(self):
        self.assertEqual(1234567.8, samples(1234567.8)[-1][1])

    def test_curve_has_settling_drops(self):
        values = [value for _, value in samples(1000.0)]
        self.assertGreater(values[8], values[7])
        self.assertLess(values[9], values[8])

    def test_packet_loss_encoding(self):
        def encode(loss):
            return (10000, 1) if loss == 100.0 else (1000, 1000 - round(loss * 10))
        self.assertEqual((1000, 1000), encode(0.0))
        self.assertEqual((1000, 1), encode(99.9))
        self.assertEqual((10000, 1), encode(100.0))


if __name__ == "__main__":
    unittest.main()

