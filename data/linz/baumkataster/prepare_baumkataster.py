#!/usr/bin/env python3
"""Convert the official Linz Baumkataster export into a web-friendly CSV."""

from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import os
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from coordinate_conversion import epsg31255_to_wgs84  # noqa: E402


SOURCE_FIELDS = [
    "Flaeche",
    "Gattung",
    "Art",
    "Sorte",
    "NameDeutsch",
    "Hoehe",
    "Schirmdurchmesser",
    "Stammumfang",
    "Typ",
    "XPos",
    "YPos",
    "lon",
    "lat",
    "BaumNr",
    "DatumExport",
]
ID_FIELDS = ("Flaeche", "BaumNr", "lon", "lat")
EMPTY_MARKERS = {"", "-"}
OUTPUT_FIELDS = ["id", *SOURCE_FIELDS]
COORDINATE_DECIMAL_PLACES = 14
PROJECTED_X_BOUNDS = (Decimal("60000"), Decimal("90000"))
PROJECTED_Y_BOUNDS = (Decimal("330000"), Decimal("370000"))
LINZ_LON_BOUNDS = (Decimal("14.0"), Decimal("14.6"))
LINZ_LAT_BOUNDS = (Decimal("48.1"), Decimal("48.5"))
COORDINATE_TOLERANCE = Decimal("0.00002")


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description=(
            "Convert the official semicolon-delimited Baumkataster CSV to "
            "comma-delimited UTF-8 CSV."
        )
    )
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=directory / "Baumkataster-source.csv",
        help="official source CSV (default: %(default)s)",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=directory / "Baumkataster.csv",
        help="prepared output CSV (default: %(default)s)",
    )
    return parser.parse_args()


def normalize(value: str | None) -> tuple[str, bool]:
    """Trim a source value and replace an empty marker with an empty string."""
    stripped = (value or "").strip()
    if stripped in EMPTY_MARKERS:
        return "", stripped != ""
    return stripped, False


def make_id(row: dict[str, str]) -> str:
    """Create a deterministic snapshot ID from the source's unique key tuple."""
    key = "\x1f".join(row[field] for field in ID_FIELDS)
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:20]
    return f"baum_{digest}"


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
    seen_keys: set[tuple[str, ...]] = set()
    seen_ids: set[str] = set()
    row_count = 0
    normalized_empty_count = 0

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
            reader = csv.DictReader(source, delimiter=";", strict=True)
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

                row: dict[str, str] = {}
                for field in SOURCE_FIELDS:
                    value, replaced_marker = normalize(source_row[field])
                    row[field] = value
                    normalized_empty_count += int(replaced_marker)

                try:
                    lon = Decimal(row["lon"])
                    lat = Decimal(row["lat"])
                except InvalidOperation as error:
                    raise ValueError(
                        f"Invalid WGS84 coordinate on line {line_number}"
                    ) from error
                if (
                    not lon.is_finite()
                    or not lat.is_finite()
                    or not (Decimal("-180") <= lon <= Decimal("180"))
                    or not (Decimal("-90") <= lat <= Decimal("90"))
                ):
                    raise ValueError(
                        f"WGS84 coordinate out of range on line {line_number}"
                    )
                row["lon"] = f"{lon:.{COORDINATE_DECIMAL_PLACES}f}"
                row["lat"] = f"{lat:.{COORDINATE_DECIMAL_PLACES}f}"
                try:
                    projected_x = Decimal(row["XPos"])
                    projected_y = Decimal(row["YPos"])
                except InvalidOperation as error:
                    raise ValueError(
                        f"Invalid EPSG:31255 coordinate on line {line_number}"
                    ) from error
                if (
                    not projected_x.is_finite()
                    or not projected_y.is_finite()
                    or not PROJECTED_X_BOUNDS[0] <= projected_x <= PROJECTED_X_BOUNDS[1]
                    or not PROJECTED_Y_BOUNDS[0] <= projected_y <= PROJECTED_Y_BOUNDS[1]
                    or not LINZ_LON_BOUNDS[0] <= lon <= LINZ_LON_BOUNDS[1]
                    or not LINZ_LAT_BOUNDS[0] <= lat <= LINZ_LAT_BOUNDS[1]
                ):
                    raise ValueError(
                        f"Coordinate outside plausible Linz bounds on line {line_number}"
                    )
                converted_lon, converted_lat = epsg31255_to_wgs84(
                    float(projected_x), float(projected_y)
                )
                if (
                    abs(Decimal(str(converted_lon)) - lon) > COORDINATE_TOLERANCE
                    or abs(Decimal(str(converted_lat)) - lat) > COORDINATE_TOLERANCE
                ):
                    raise ValueError(
                        "EPSG:31255 and WGS84 coordinates disagree on line "
                        f"{line_number}"
                    )

                key = tuple(row[field] for field in ID_FIELDS)
                if key in seen_keys:
                    raise ValueError(
                        f"Duplicate source key on line {line_number}: {key}"
                    )
                seen_keys.add(key)

                tree_id = make_id(row)
                if tree_id in seen_ids:
                    raise ValueError(
                        f"Generated ID collision on line {line_number}: {tree_id}"
                    )
                seen_ids.add(tree_id)

                writer.writerow({"id": tree_id, **row})
                row_count += 1

            temporary.flush()
            os.fsync(temporary.fileno())
            os.chmod(temporary_path, 0o644)
            os.replace(temporary_path, output_path)
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise

    print(f"Wrote {row_count:,} rows to {output_path}")
    print(f"Generated {len(seen_ids):,} unique snapshot IDs")
    print(f"Replaced {normalized_empty_count:,} '-' markers with empty fields")


def main() -> None:
    args = parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
