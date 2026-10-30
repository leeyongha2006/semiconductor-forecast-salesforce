import os
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import ppt_summary_parser as parser  # noqa: E402

SECTIONS = ["Project Info", "Sales Info", "MP Plan"]

ROWS = [
    ["Project Info", ""],
    ["", "Application : Mobile AP"],
    ["", "End user：TBD"],
    ["", "PKG type", "FO-WLP"],
    ["Sales Info", ""],
    ["", "Final Quote", "$1,200.50"],
    ["", "Ship to : Demo Customer"],
    ["MP Plan", "Start date : 26.03.15"],
]


class PptSummaryParserTest(unittest.TestCase):

    def test_groups_rows_into_sections(self):
        sections = parser.parse_sections(ROWS, SECTIONS)
        self.assertEqual("Mobile AP", sections["project info"]["application"])
        self.assertEqual("FO-WLP", sections["project info"]["pkg type"])
        self.assertEqual("26.03.15", sections["mp plan"]["start date"])

    def test_builds_salesforce_body_and_skips_placeholders(self):
        sections = parser.parse_sections(ROWS, SECTIONS)
        body = parser.to_salesforce_fields(sections, {"demo customer": "001000000000001"})
        self.assertEqual(
            {
                "Application": "Mobile AP",
                "PackageType": "FO-WLP",
                "FinalQuote": 1200.5,
                "ShipTo": "001000000000001",
                "MassProductionStart": "2026-03-15",
            },
            body,
        )
        self.assertNotIn("EndUser", body)

    def test_unknown_account_is_left_out(self):
        sections = parser.parse_sections(ROWS, SECTIONS)
        self.assertNotIn("ShipTo", parser.to_salesforce_fields(sections, {}))

    def test_date_formats(self):
        self.assertEqual(date(2026, 3, 15), parser.to_date("260315"))
        self.assertEqual(date(2026, 3, 15), parser.to_date("2026-03-15"))
        self.assertIsNone(parser.to_date("2026-13-40"))
        self.assertIsNone(parser.to_date("Q2"))

    def test_rows_before_first_section_are_ignored(self):
        rows = [["Title", "Project Summary"]] + ROWS
        self.assertNotIn("title", parser.parse_sections(rows, SECTIONS))

    def test_processing_status(self):
        self.assertEqual("None", parser.processing_status(False, {}))
        self.assertEqual("Fail", parser.processing_status(True, {}))
        self.assertEqual("Pass", parser.processing_status(True, {"Application": "x"}))


if __name__ == "__main__":
    unittest.main()
