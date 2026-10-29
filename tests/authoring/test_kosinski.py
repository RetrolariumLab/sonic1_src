import unittest
from scripts.authoring.kosinski import decode


class KosinskiTests(unittest.TestCase):
    def test_literal_and_end_marker_consumption(self):
        result = decode(bytes([5, 0, 65, 0, 0, 0, 99]))
        self.assertEqual(result.data, b"A")
        self.assertEqual(result.consumed, 6)

    def test_refill_precedes_sixteenth_literal(self):
        raw = b"\xff\xff" + b"A" * 15 + b"\x02\x00" + b"A" + b"\0\0\0"
        result = decode(raw)
        self.assertEqual(result.data, b"A" * 16)
        self.assertEqual(result.consumed, len(raw))

    def test_bad_streams_and_output_capacity_are_rejected(self):
        for raw in (b"", b"\0", bytes([0, 0, 255])):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                decode(raw)
        with self.assertRaisesRegex(ValueError, "capacity"):
            decode(bytes([5, 0, 65, 0, 0, 0]), max_output=0)
