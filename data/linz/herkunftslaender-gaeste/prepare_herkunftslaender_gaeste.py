#!/usr/bin/env python3
"""Convert the official Linz guest-origin export into a tidy UTF-8 CSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
from pathlib import Path
import tempfile


YEAR = 2024
ORIGIN_FIELD = "ständiger Wohnsitz der Fremden"
SOURCE_FIELDS = [
    ORIGIN_FIELD,
    *[
        f"{metric} {quarter}.Quartal"
        for metric in ("Fremdenmeldungen", "Übernachtungen")
        for quarter in range(1, 5)
    ],
]
OUTPUT_FIELDS = [
    "id",
    "jahr",
    "quartal",
    "herkunft",
    "herkunft_typ",
    "iso2",
    "ankuenfte",
    "uebernachtungen",
]

# ISO 3166-1 alpha-2 codes are supplied only for source rows that represent one
# unambiguous country. Mixed regions and source totals deliberately remain blank.
COUNTRY_CODES = {
    "Österreich": "AT",
    "Australien": "AU",
    "Belgien": "BE",
    "Brasilien": "BR",
    "Bulgarien": "BG",
    "Dänemark": "DK",
    "Deutschland": "DE",
    "Estland": "EE",
    "Finnland": "FI",
    "Griechenland": "GR",
    "Indien": "IN",
    "Irland (Republik)": "IE",
    "Island": "IS",
    "Israel": "IL",
    "Italien": "IT",
    "Japan": "JP",
    "Kanada": "CA",
    "Kroatien": "HR",
    "Lettland": "LV",
    "Litauen": "LT",
    "Luxemburg": "LU",
    "Malta": "MT",
    "Neuseeland": "NZ",
    "Niederlande": "NL",
    "Norwegen": "NO",
    "Polen": "PL",
    "Portugal": "PT",
    "Rumänien": "RO",
    "Russland": "RU",
    "Saudi-Arabien": "SA",
    "Schweden": "SE",
    "Slowakei": "SK",
    "Slowenien": "SI",
    "Spanien": "ES",
    "Südafrika": "ZA",
    "Südkorea": "KR",
    "Taiwan": "TW",
    "Tschechische Republik": "CZ",
    "Türkei": "TR",
    "Ukraine": "UA",
    "Ungarn": "HU",
    "USA": "US",
    "Ver. Arabische Emirate": "AE",
    "Vereinigtes Königreich": "GB",
    "Zypern": "CY",
}
TOTAL_ORIGINS = {"Ausland"}
GROUP_ORIGINS = {
    "darunter Wien",
    "Arab. Länder in Asien 1)",
    "China 2)",
    "Frankreich (inkl. Monaco)",
    "übrige GUS 3)",
    "ehem. Jugoslawien 4)",
    "Schweiz, Liechtenstein",
    "Südostasien 5)",
    "Übriges Afrika",
    "Übriges Asien",
    "Zentral- und Südamerika 6)",
    "Übriges Ausland",
}
EXPECTED_ORIGIN_COUNT = 58
EXPECTED_ORIGINS = set(COUNTRY_CODES) | TOTAL_ORIGINS | GROUP_ORIGINS


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description=(
            "Convert the official Latin-1, semicolon-delimited guest-origin CSV "
            "to tidy, comma-delimited UTF-8 CSV."
        )
    )
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=directory / "Herkunftslaender-source.csv",
        help="official 2024 source CSV (default: %(default)s)",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=directory / "Herkunftslaender.csv",
        help="prepared output CSV (default: %(default)s)",
    )
    return parser.parse_args()


def validate_header(fieldnames: list[str] | None) -> None:
    if fieldnames != SOURCE_FIELDS:
        raise ValueError(
            "Unexpected source columns.\n"
            f"Expected: {SOURCE_FIELDS}\n"
            f"Received: {fieldnames}"
        )


def parse_count(value: str | None, *, field: str, line_number: int) -> int:
    normalized = (value or "").strip()
    if not normalized.isascii() or not normalized.isdecimal():
        raise ValueError(
            f"Invalid non-negative integer in {field!r} on line {line_number}: "
            f"{value!r}"
        )
    return int(normalized)


def origin_type(origin: str) -> str:
    if origin in COUNTRY_CODES:
        return "land"
    if origin in TOTAL_ORIGINS:
        return "summe"
    if origin in GROUP_ORIGINS:
        return "gruppe"
    raise ValueError(f"Unexpected origin label: {origin!r}")


def make_id(origin: str, quarter: int) -> str:
    key = f"{YEAR}\x1f{quarter}\x1f{origin}"
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:20]
    return f"herkunft_{digest}"


def convert(input_path: Path, output_path: Path) -> None:
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must be different")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    origins: set[str] = set()
    seen_ids: set[str] = set()
    output_count = 0
    country_row_count = 0

    with (
        input_path.open("r", encoding="iso-8859-1", newline="") as source,
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

                origin = (source_row[ORIGIN_FIELD] or "").strip()
                if not origin:
                    raise ValueError(f"Missing origin on line {line_number}")
                if origin in origins:
                    raise ValueError(
                        f"Duplicate origin on line {line_number}: {origin!r}"
                    )
                origins.add(origin)

                kind = origin_type(origin)
                iso2 = COUNTRY_CODES.get(origin, "")
                country_row_count += int(kind == "land")

                for quarter in range(1, 5):
                    arrivals_field = f"Fremdenmeldungen {quarter}.Quartal"
                    nights_field = f"Übernachtungen {quarter}.Quartal"
                    record_id = make_id(origin, quarter)
                    if record_id in seen_ids:
                        raise ValueError(f"Generated ID collision: {record_id}")
                    seen_ids.add(record_id)

                    writer.writerow(
                        {
                            "id": record_id,
                            "jahr": YEAR,
                            "quartal": quarter,
                            "herkunft": origin,
                            "herkunft_typ": kind,
                            "iso2": iso2,
                            "ankuenfte": parse_count(
                                source_row[arrivals_field],
                                field=arrivals_field,
                                line_number=line_number,
                            ),
                            "uebernachtungen": parse_count(
                                source_row[nights_field],
                                field=nights_field,
                                line_number=line_number,
                            ),
                        }
                    )
                    output_count += 1

            if len(origins) != EXPECTED_ORIGIN_COUNT:
                raise ValueError(
                    f"Expected {EXPECTED_ORIGIN_COUNT} origins, received {len(origins)}"
                )
            if origins != EXPECTED_ORIGINS:
                raise ValueError(
                    "Origin labels differ from the reviewed allowlist. "
                    f"Missing: {sorted(EXPECTED_ORIGINS - origins)}; "
                    f"unexpected: {sorted(origins - EXPECTED_ORIGINS)}"
                )

            temporary.flush()
            os.fsync(temporary.fileno())
            os.chmod(temporary_path, 0o644)
            os.replace(temporary_path, output_path)
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise

    print(f"Wrote {output_count:,} rows to {output_path}")
    print(f"Generated {len(seen_ids):,} unique snapshot IDs")
    print(f"Mapped {country_row_count:,} origins to unambiguous ISO-2 codes")
    print(f"Preserved {len(origins) - country_row_count:,} totals and groups")


def main() -> None:
    args = parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
