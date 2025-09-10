#!/usr/bin/env python3

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def redact_name(original_name):
    """Redact a name keeping the last 5 characters.

    For names <= 5 chars, prefix with REDACTED_.
    For names > 5 chars, use REDACTED_ + last 5 chars.
    """
    if len(original_name) <= 5:
        return f"REDACTED_{original_name}"
    else:
        return f"REDACTED_{original_name[-5:]}"


def redact_xml_content(input_file, output_file, redact_names=False, redact_output=False):
    """Redact XML content based on the specified options.

    Args:
        input_file: Path to input XML file
        output_file: Path to output XML file
        redact_names: Whether to redact test names
        redact_output: Whether to redact test output/messages
    """
    try:
        # Parse the XML file
        tree = ET.parse(input_file)
        root = tree.getroot()

        if redact_names:
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

        if redact_output:
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
    parser = argparse.ArgumentParser(description="Redact JUnit XML test results")
    parser.add_argument("input_file", help="Input XML file path")
    parser.add_argument("output_file", help="Output XML file path")
    parser.add_argument("--redact-names", action="store_true", help="Redact test names and class names")
    parser.add_argument("--redact-output", action="store_true", help="Redact test output and error messages")

    args = parser.parse_args()

    # Validate input file exists
    if not Path(args.input_file).exists():
        print(f"Error: Input file {args.input_file} does not exist", file=sys.stderr)
        sys.exit(1)

    # If no redaction flags specified, just copy the file
    if not args.redact_names and not args.redact_output:
        try:
            import shutil

            shutil.copy2(args.input_file, args.output_file)
            print(f"No redaction requested, copied file: {args.input_file} -> {args.output_file}")
            sys.exit(0)
        except Exception as e:
            print(f"Failed to copy file: {e}", file=sys.stderr)
            sys.exit(1)

    # Perform redaction
    success = redact_xml_content(
        args.input_file, args.output_file, redact_names=args.redact_names, redact_output=args.redact_output
    )

    if success:
        print(f"Successfully redacted XML: {args.input_file} -> {args.output_file}")
        sys.exit(0)
    else:
        print(f"Failed to redact XML file: {args.input_file}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
