from pathlib import Path
import tempfile
import unittest
from scripts.build.listing import symbols
from scripts.build.project import ROOT


class ListingTests(unittest.TestCase):
    def parse(self, text, names):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="listing-test-") as folder:
            path = Path(folder) / "fixture.lst"
            path.write_bytes(text.encode())
            return symbols(path, set(names))

    def test_equates_use_values_instead_of_the_current_program_counter(self):
        value = self.parse(
            "(2) 53/FFFFFFFFFFFFF000 : =$FFFFFFFFFFFFD000   Player: equ ObjSpace\n(3) 13/ 0 : =1FFCH   Stack: equ 1FFCh\n(1) 9/ 200 : 4E75    Next: rts\n",
            ["Player", "Stack", "Next"],
        )
        self.assertEqual(value, {"Player": 0xFFD000, "Stack": 0x1FFC, "Next": 0x200})

    def test_macro_repeated_definition_is_not_a_second_address(self):
        value = self.parse("1/ 200 : (MACRO) Label: wrapper\n1/ 200 : =$200 Label: label *\n", ["Label"])
        self.assertEqual(value["Label"], 0x200)
        with self.assertRaisesRegex(ValueError, "distinct definitions"):
            self.parse("1/ 200 : Label:\n2/ 202 : Label:\n", ["Label"])

    def test_diagnostic_strings_are_not_symbol_definitions(self):
        with self.assertRaises(ValueError):
            self.parse('1/ 200 : message "Missing:"\n', ["Missing"])
