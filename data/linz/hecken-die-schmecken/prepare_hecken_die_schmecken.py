#!/usr/bin/env python3
"""Convert the official Hecken die Schmecken export into a web-friendly CSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
from pathlib import Path
import tempfile


SOURCE_FIELDS = ["Standort", "Beschreibung", "Art"]
OUTPUT_FIELDS = ["id", "standort", "beschreibung", "art"]


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description=(
            "Convert the official Hecken die Schmecken CSV to normalized, "
            "comma-delimited UTF-8 CSV."
        )
    )
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=directory / "Hecken-die-schmecken-source.csv",
        help="official source CSV (default: %(default)s)",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=directory / "Hecken-die-schmecken.csv",
        help="prepared output CSV (default: %(default)s)",
    )
    return parser.parse_args()


def normalize(value: str | None) -> tuple[str, bool]:
    """Trim a value and replace embedded line breaks with spaces."""
    original = value or ""
    normalized = " ".join(
        part.strip()
        for part in original.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ).strip()
    return normalized, normalized != original


def make_id(standort: str) -> str:
    """Create a stable ID from the source's unique location designation."""
    digest = hashlib.sha256(standort.encode("utf-8")).hexdigest()[:20]
    return f"hecke_{digest}"


def validate_header(fieldnames: list[str] | None) -> None:
    if fieldnames != SOURCE_FIELDS:
        raise ValueError(
            "Unexpected source columns.\n"
            f"Expected: {SOURCE_FIELDS}\n"
            f"Received: {fieldnames}"
        )


def convert(input_path: Path, output_path: Path) -> None:
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must be different")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    seen_locations: set[str] = set()
    seen_ids: set[str] = set()
    row_count = 0
    normalized_value_count = 0
    empty_value_count = 0

    with (
        input_path.open("r", encoding="utf-8-sig", newline="") as source,
        tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="",
            dir=output_path.parent,
            prefix=f".{output_path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary,
    ):
        temporary_path = Path(temporary.name)
        try:
            reader = csv.DictReader(source, delimiter=",", strict=True)
            validate_header(reader.fieldnames)
            writer = csv.DictWriter(
                temporary,
                fieldnames=OUTPUT_FIELDS,
                delimiter=",",
                lineterminator="\n",
                quoting=csv.QUOTE_MINIMAL,
            )
            writer.writeheader()

            for line_number, source_row in enumerate(reader, start=2):
                if None in source_row:
                    raise ValueError(f"Unexpected extra column on line {line_number}")
                if any(source_row[field] is None for field in SOURCE_FIELDS):
                    raise ValueError(f"Missing column value on line {line_number}")

                normalized: dict[str, str] = {}
                for field in SOURCE_FIELDS:
                    value, changed = normalize(source_row[field])
                    normalized[field] = value
                    normalized_value_count += int(changed)
                    empty_value_count += int(value == "")

                standort = normalized["Standort"]
                if not standort:
                    raise ValueError(f"Missing Standort on line {line_number}")
                if standort in seen_locations:
                    raise ValueError(
                        f"Duplicate Standort on line {line_number}: {standort!r}"
                    )
                seen_locations.add(standort)
                record_id = make_id(standort)
                if record_id in seen_ids:
                    raise ValueError(
                        f"Generated ID collision on line {line_number}: {record_id}"
                    )
                seen_ids.add(record_id)

                writer.writerow(
                    {
                        "id": record_id,
                        "standort": standort,
                        "beschreibung": normalized["Beschreibung"],
                        "art": normalized["Art"],
                    }
                )
                row_count += 1

            temporary.flush()
            os.fsync(temporary.fileno())
            os.chmod(temporary_path, 0o644)
            os.replace(temporary_path, output_path)
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise

    print(f"Wrote {row_count:,} rows to {output_path}")
    print(f"Generated {len(seen_ids):,} stable unique IDs from Standort")
    print(f"Normalized {normalized_value_count:,} source values")
    print(f"Preserved {empty_value_count:,} empty values")


def main() -> None:
    args = parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
