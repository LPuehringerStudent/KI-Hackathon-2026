#!/usr/bin/env python3
"""Convert the official Linz public-toilet export into a web-friendly CSV."""

from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import os
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from coordinate_conversion import epsg31255_to_wgs84  # noqa: E402


SOURCE_FIELDS = [
    "Nr.",
    "Art",
    "Wc Anlagen ",
    "X",
    "Y",
    "barriere\nfrei",
    "Euro-\nKey",
    "Öffnungszeiten",
    "Wickel\ntisch",
    "Winter\nsperre",
    "Anmerkung",
]
OUTPUT_FIELDS = [
    "id",
    "nummer",
    "art",
    "name",
    "epsg31255_x",
    "epsg31255_y",
    "lon",
    "lat",
    "barrierefrei",
    "eurokey",
    "oeffnungszeiten",
    "wickeltisch",
    "wintersperre",
    "anmerkung",
]


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Convert the Linz WC CSV.")
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=directory / "WC_Anlagen-source.csv",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=directory / "WC-Anlagen.csv",
    )
    return parser.parse_args()


def clean(value: str | None) -> str:
    return " ".join((value or "").split())


def boolean(value: str | None, *, field: str, line_number: int) -> str:
    normalized = clean(value).casefold()
    if normalized not in {"ja", "nein"}:
        raise ValueError(
            f"Unexpected boolean in {field!r} on line {line_number}: {value!r}"
        )
    return "true" if normalized == "ja" else "false"


def coordinate(value: str | None, *, field: str, line_number: int) -> Decimal:
    try:
        result = Decimal(clean(value).replace(",", "."))
    except InvalidOperation as error:
        raise ValueError(
            f"Invalid coordinate in {field!r} on line {line_number}: {value!r}"
        ) from error
    if not result.is_finite():
        raise ValueError(f"Non-finite coordinate on line {line_number}")
    return result


def convert(input_path: Path, output_path: Path) -> None:
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must be different")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    seen_ids: set[str] = set()
    row_count = 0

    with (
        input_path.open(encoding="utf-8-sig", newline="") as source,
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
            if reader.fieldnames != SOURCE_FIELDS:
                raise ValueError(
                    f"Unexpected source columns.\nExpected: {SOURCE_FIELDS}\n"
                    f"Received: {reader.fieldnames}"
                )
            writer = csv.DictWriter(
                temporary, fieldnames=OUTPUT_FIELDS, lineterminator="\n"
            )
            writer.writeheader()
            for line_number, source_row in enumerate(reader, start=2):
                if None in source_row or any(
                    source_row[field] is None for field in SOURCE_FIELDS
                ):
                    raise ValueError(f"Malformed row on line {line_number}")
                if not any(clean(value) for value in source_row.values()):
                    continue
                number = clean(source_row["Nr."])
                name = clean(source_row["Wc Anlagen "])
                if not number or not name:
                    raise ValueError(f"Missing number or name on line {line_number}")
                record_id = f"wc_{number.casefold()}"
                if record_id in seen_ids:
                    raise ValueError(f"Duplicate WC ID on line {line_number}")
                seen_ids.add(record_id)

                easting = coordinate(source_row["X"], field="X", line_number=line_number)
                northing = coordinate(source_row["Y"], field="Y", line_number=line_number)
                if (
                    not Decimal("60000") <= easting <= Decimal("90000")
                    or not Decimal("330000") <= northing <= Decimal("370000")
                ):
                    raise ValueError(f"Out-of-range coordinate on line {line_number}")
                lon, lat = epsg31255_to_wgs84(float(easting), float(northing))
                writer.writerow(
                    {
                        "id": record_id,
                        "nummer": number,
                        "art": clean(source_row["Art"]),
                        "name": name,
                        "epsg31255_x": format(easting.normalize(), "f"),
                        "epsg31255_y": format(northing.normalize(), "f"),
                        "lon": f"{lon:.8f}",
                        "lat": f"{lat:.8f}",
                        "barrierefrei": boolean(
                            source_row["barriere\nfrei"],
                            field="barrierefrei",
                            line_number=line_number,
                        ),
                        "eurokey": boolean(
                            source_row["Euro-\nKey"],
                            field="Euro-Key",
                            line_number=line_number,
                        ),
                        "oeffnungszeiten": clean(source_row["Öffnungszeiten"]),
                        "wickeltisch": boolean(
                            source_row["Wickel\ntisch"],
                            field="Wickeltisch",
                            line_number=line_number,
                        ),
                        "wintersperre": clean(source_row["Winter\nsperre"]),
                        "anmerkung": clean(source_row["Anmerkung"]),
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

    print(f"Wrote {row_count:,} public toilets to {output_path}")
    print(f"Generated {len(seen_ids):,} unique IDs")
    print(f"Converted {row_count:,} coordinates to WGS84")


def main() -> None:
    args = parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
