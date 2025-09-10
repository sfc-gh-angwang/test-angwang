#!/usr/bin/env python3

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def redact_name(original_name):
    """Redact a name keeping the last 5 characters.

    For names <= 5 chars, prefix with REDACTED_.
    For names > 5 chars, use REDACTED_ + last 5 chars.
    """
    if len(original_name) <= 5:
        return f"[REDACTED]_{original_name}"
    else:
        return f"[REDACTED]_{original_name[-5:]}"


def redact_xml_content(input_file, output_file):
    """Redact all sensitive content in XML file.

    Args:
        input_file: Path to input XML file
        output_file: Path to output XML file
    """
    try:
        # Parse the XML file
        tree = ET.parse(input_file)
        root = tree.getroot()

        # Redact names in testsuites elements
        for testsuites in root.iter("testsuites"):
            if "name" in testsuites.attrib:
                testsuites.attrib["name"] = redact_name(testsuites.attrib["name"])

        # Redact names in testsuite elements
        for testsuite in root.iter("testsuite"):
            if "name" in testsuite.attrib:
                testsuite.attrib["name"] = redact_name(testsuite.attrib["name"])

        # Redact names and classnames in testcase elements
        for testcase in root.iter("testcase"):
            if "name" in testcase.attrib:
                testcase.attrib["name"] = redact_name(testcase.attrib["name"])
            if "classname" in testcase.attrib:
                testcase.attrib["classname"] = redact_name(testcase.attrib["classname"])

        # Redact failure elements
        for failure in root.iter("failure"):
            if "message" in failure.attrib:
                failure.attrib["message"] = "[REDACTED]"
            if failure.text:
                failure.text = "[REDACTED]"

        # Redact error elements
        for error in root.iter("error"):
            if "message" in error.attrib:
                error.attrib["message"] = "[REDACTED]"
            if error.text:
                error.text = "[REDACTED]"

        # Redact skipped elements
        for skipped in root.iter("skipped"):
            if "message" in skipped.attrib:
                skipped.attrib["message"] = "[REDACTED]"
            if skipped.text:
                skipped.text = "[REDACTED]"

        # Redact system-out elements
        for system_out in root.iter("system-out"):
            if system_out.text:
                system_out.text = "[REDACTED]"

        # Redact system-err elements
        for system_err in root.iter("system-err"):
            if system_err.text:
                system_err.text = "[REDACTED]"

        # Write the modified XML to output file
        tree.write(output_file, encoding="utf-8", xml_declaration=True)
        return True

    except ET.ParseError as e:
        print(f"Error parsing XML file {input_file}: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error processing XML file {input_file}: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) != 3:
        print("Usage: redact_xml.py <input_file> <output_file>", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # Validate input file exists
    if not Path(input_file).exists():
        print(f"Error: Input file {input_file} does not exist", file=sys.stderr)
        sys.exit(1)

    # Perform redaction
    success = redact_xml_content(input_file, output_file)

    if success:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
