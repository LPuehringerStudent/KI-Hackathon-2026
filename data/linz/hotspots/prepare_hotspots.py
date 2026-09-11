#!/usr/bin/env python3
"""Convert the official Linz hotspot exports into student-friendly CSV files."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
from decimal import Decimal, InvalidOperation
import hashlib
import os
from pathlib import Path
import re
import shutil
import tempfile


LOCATION_SOURCE_FIELDS = [
    "Nummer",
    "Latitude",
    "Longitude",
    "Name",
    "Kurztext",
    "Start im Jahr",
    "Ende im Jahr",
    "Stadt",
    "Postleitzahl",
    "Straße",
    "Homepage",
    "",
]
LOCATION_OUTPUT_FIELDS = [
    "id",
    "nummer",
    "name",
    "lat",
    "lon",
    "kurztext",
    "start_jahr",
    "ende_jahr",
    "status_2022",
    "stadt",
    "plz",
    "strasse",
    "homepage",
]
USAGE_SOURCE_FIELDS = [
    "Hotspot/Anzahl Clients",
    "01.01.2022",
    "01.02.2022",
    "01.03.2022",
    "01.04.2022",
    "01.05.2022",
    "01.06.2022",
    "01.07.2022",
]
USAGE_OUTPUT_FIELDS = [
    "id",
    "standort_id",
    "name",
    "jahr",
    "monat",
    "anzahl_clients",
]
EXPECTED_LOCATION_COUNT = 134
EXPECTED_USAGE_LOCATION_COUNT = 107
EXPECTED_UNLINKED_USAGE_NAMES = {"Rotes Kreuz"}
COORDINATE_DECIMAL_PLACES = 14
VALID_STATUSES = {"ok", "neu", "offline", "defekt"}
LINZ_LAT_BOUNDS = (Decimal("48.1"), Decimal("48.5"))
LINZ_LON_BOUNDS = (Decimal("14.0"), Decimal("14.6"))

# Three source typos or spelling variants can be matched unambiguously. The
# usage name "Rotes Kreuz" is deliberately absent because two locations match.
USAGE_NAME_ALIASES = {
    "innovationsbuero": "Innovationisbuero",
    "wimhoelzplatz": "Wimhölzelplatz",
    "zahnmuseum": "Zahnmuesum",
}


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Convert the two official 2022 Linz hotspot CSV exports."
    )
    parser.add_argument(
        "--locations-input",
        type=Path,
        default=directory / "Hotspot-Standorte-source.csv",
        help="official location source CSV (default: %(default)s)",
    )
    parser.add_argument(
        "--usage-input",
        type=Path,
        default=directory / "Hotspot-Nutzung-source.csv",
        help="official usage source CSV (default: %(default)s)",
    )
    parser.add_argument(
        "--locations-output",
        type=Path,
        default=directory / "Hotspot-Standorte.csv",
        help="prepared location CSV (default: %(default)s)",
    )
    parser.add_argument(
        "--usage-output",
        type=Path,
        default=directory / "Hotspot-Nutzung.csv",
        help="prepared usage CSV (default: %(default)s)",
    )
    return parser.parse_args()


def normalize(value: str | None) -> str:
    return (value or "").strip()


def normalize_name(value: str) -> str:
    normalized = value.casefold().translate(
        str.maketrans({"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"})
    )
    normalized = re.sub(r"\s*\([^)]*\)\s*", " ", normalized)
    return re.sub(r"[^a-z0-9]+", "", normalized)


def validate_header(
    fieldnames: list[str] | None, expected: list[str], *, source_name: str
) -> None:
    if fieldnames != expected:
        raise ValueError(
            f"Unexpected {source_name} columns.\n"
            f"Expected: {expected}\n"
            f"Received: {fieldnames}"
        )


def parse_coordinate(
    value: str | None,
    *,
    minimum: Decimal,
    maximum: Decimal,
    field: str,
    line_number: int,
) -> str:
    normalized = normalize(value).replace(",", ".")
    try:
        coordinate = Decimal(normalized)
    except InvalidOperation as error:
        raise ValueError(
            f"Invalid WGS84 {field} on line {line_number}: {value!r}"
        ) from error
    if not coordinate.is_finite() or not minimum <= coordinate <= maximum:
        raise ValueError(
            f"WGS84 {field} out of range on line {line_number}: {value!r}"
        )
    return f"{coordinate:.{COORDINATE_DECIMAL_PLACES}f}"


def parse_optional_year(
    value: str | None, *, field: str, line_number: int, zero_is_empty: bool = False
) -> str:
    normalized = normalize(value)
    if normalized == "" or (zero_is_empty and normalized == "0"):
        return ""
    if (
        not normalized.isascii()
        or not normalized.isdecimal()
        or not 1900 <= int(normalized) <= 2022
    ):
        raise ValueError(f"Invalid {field} on line {line_number}: {value!r}")
    return normalized


def parse_optional_count(
    value: str | None, *, field: str, line_number: int
) -> str:
    normalized = normalize(value)
    if normalized == "":
        return ""
    if not normalized.isascii() or not normalized.isdecimal():
        raise ValueError(
            f"Invalid non-negative integer in {field!r} on line {line_number}: "
            f"{value!r}"
        )
    return str(int(normalized))


def make_id(prefix: str, *parts: str) -> str:
    digest = hashlib.sha256("\x1f".join(parts).encode("utf-8")).hexdigest()[:20]
    return f"{prefix}_{digest}"


def read_locations(
    input_path: Path,
) -> tuple[list[dict[str, str]], dict[str, list[dict[str, str]]]]:
    rows: list[dict[str, str]] = []
    names: dict[str, list[dict[str, str]]] = {}
    seen_ids: set[str] = set()

    with input_path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source, strict=True)
        validate_header(
            reader.fieldnames, LOCATION_SOURCE_FIELDS, source_name="location source"
        )

        for line_number, source_row in enumerate(reader, start=2):
            if None in source_row:
                raise ValueError(f"Unexpected extra column on line {line_number}")
            if any(source_row[field] is None for field in LOCATION_SOURCE_FIELDS):
                raise ValueError(f"Missing column value on line {line_number}")

            name = normalize(source_row["Name"])
            if not name:
                raise ValueError(f"Missing location name on line {line_number}")
            lat = parse_coordinate(
                source_row["Latitude"],
                minimum=LINZ_LAT_BOUNDS[0],
                maximum=LINZ_LAT_BOUNDS[1],
                field="latitude",
                line_number=line_number,
            )
            lon = parse_coordinate(
                source_row["Longitude"],
                minimum=LINZ_LON_BOUNDS[0],
                maximum=LINZ_LON_BOUNDS[1],
                field="longitude",
                line_number=line_number,
            )
            status = normalize(source_row[""])
            if status not in VALID_STATUSES:
                raise ValueError(
                    f"Unknown location status on line {line_number}: {status!r}"
                )

            location_id = make_id(
                "hotspot",
                normalize(source_row["Nummer"]),
                name,
                lat,
                lon,
            )
            if location_id in seen_ids:
                raise ValueError(
                    f"Generated location ID collision on line {line_number}: "
                    f"{location_id}"
                )
            seen_ids.add(location_id)

            row = {
                "id": location_id,
                "nummer": normalize(source_row["Nummer"]),
                "name": name,
                "lat": lat,
                "lon": lon,
                "kurztext": normalize(source_row["Kurztext"]),
                "start_jahr": parse_optional_year(
                    source_row["Start im Jahr"],
                    field="start year",
                    line_number=line_number,
                ),
                "ende_jahr": parse_optional_year(
                    source_row["Ende im Jahr"],
                    field="end year",
                    line_number=line_number,
                    zero_is_empty=True,
                ),
                "status_2022": status,
                "stadt": normalize(source_row["Stadt"]),
                "plz": normalize(source_row["Postleitzahl"]),
                "strasse": normalize(source_row["Straße"]),
                "homepage": normalize(source_row["Homepage"]),
            }
            rows.append(row)
            names.setdefault(normalize_name(name), []).append(row)

    if len(rows) != EXPECTED_LOCATION_COUNT:
        raise ValueError(
            f"Expected {EXPECTED_LOCATION_COUNT} locations, received {len(rows)}"
        )
    return rows, names


def resolve_location_id(
    usage_name: str, locations_by_name: dict[str, list[dict[str, str]]]
) -> str:
    alias = USAGE_NAME_ALIASES.get(normalize_name(usage_name))
    lookup_name = alias or usage_name
    matches = locations_by_name.get(normalize_name(lookup_name), [])
    return matches[0]["id"] if len(matches) == 1 else ""


def read_usage(
    input_path: Path, locations_by_name: dict[str, list[dict[str, str]]]
) -> tuple[list[dict[str, str]], int, set[str]]:
    rows: list[dict[str, str]] = []
    seen_names: set[str] = set()
    seen_ids: set[str] = set()
    linked_names = 0
    unlinked_names: set[str] = set()

    with input_path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source, strict=True)
        validate_header(
            reader.fieldnames, USAGE_SOURCE_FIELDS, source_name="usage source"
        )

        for line_number, source_row in enumerate(reader, start=2):
            if None in source_row:
                raise ValueError(f"Unexpected extra column on line {line_number}")
            if any(source_row[field] is None for field in USAGE_SOURCE_FIELDS):
                raise ValueError(f"Missing column value on line {line_number}")

            name = normalize(source_row["Hotspot/Anzahl Clients"])
            if not name:
                raise ValueError(f"Missing usage name on line {line_number}")
            if name in seen_names:
                raise ValueError(f"Duplicate usage name on line {line_number}: {name}")
            seen_names.add(name)

            location_id = resolve_location_id(name, locations_by_name)
            linked_names += int(bool(location_id))
            if not location_id:
                unlinked_names.add(name)
            for date_field in USAGE_SOURCE_FIELDS[1:]:
                month_date = datetime.strptime(date_field, "%d.%m.%Y")
                record_id = make_id("nutzung", name, month_date.strftime("%Y-%m"))
                if record_id in seen_ids:
                    raise ValueError(f"Generated usage ID collision: {record_id}")
                seen_ids.add(record_id)

                rows.append(
                    {
                        "id": record_id,
                        "standort_id": location_id,
                        "name": name,
                        "jahr": str(month_date.year),
                        "monat": str(month_date.month),
                        "anzahl_clients": parse_optional_count(
                            source_row[date_field],
                            field=date_field,
                            line_number=line_number,
                        ),
                    }
                )

    if len(seen_names) != EXPECTED_USAGE_LOCATION_COUNT:
        raise ValueError(
            f"Expected {EXPECTED_USAGE_LOCATION_COUNT} usage locations, "
            f"received {len(seen_names)}"
        )
    if unlinked_names != EXPECTED_UNLINKED_USAGE_NAMES:
        raise ValueError(
            "Unexpected usage/location join result. "
            f"Expected unresolved names {sorted(EXPECTED_UNLINKED_USAGE_NAMES)}, "
            f"received {sorted(unlinked_names)}"
        )
    return rows, linked_names, unlinked_names


def prepare_output(
    output_path: Path, fieldnames: list[str], rows: list[dict[str, str]]
) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        newline="",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
        try:
            writer = csv.DictWriter(
                temporary,
                fieldnames=fieldnames,
                delimiter=",",
                lineterminator="\n",
                quoting=csv.QUOTE_MINIMAL,
            )
            writer.writeheader()
            writer.writerows(rows)
            temporary.flush()
            os.fsync(temporary.fileno())
            os.chmod(temporary_path, 0o644)
            return temporary_path
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise


def publish_outputs(outputs: list[tuple[Path, Path]]) -> None:
    """Publish related files as one rollback-safe transaction."""
    backups: list[tuple[Path, Path | None]] = []
    try:
        for _, output_path in outputs:
            backup_path: Path | None = None
            if output_path.exists():
                with tempfile.NamedTemporaryFile(
                    dir=output_path.parent,
                    prefix=f".{output_path.name}.",
                    suffix=".bak",
                    delete=False,
                ) as backup:
                    backup_path = Path(backup.name)
                try:
                    shutil.copy2(output_path, backup_path)
                except Exception:
                    backup_path.unlink(missing_ok=True)
                    raise
            backups.append((output_path, backup_path))
        for temporary_path, output_path in outputs:
            os.replace(temporary_path, output_path)
    except Exception:
        for output_path, backup_path in backups:
            if backup_path is None:
                output_path.unlink(missing_ok=True)
            elif backup_path.exists():
                os.replace(backup_path, output_path)
        raise
    finally:
        for temporary_path, _ in outputs:
            temporary_path.unlink(missing_ok=True)
        for _, backup_path in backups:
            if backup_path is not None:
                backup_path.unlink(missing_ok=True)


def convert(
    locations_input: Path,
    usage_input: Path,
    locations_output: Path,
    usage_output: Path,
) -> None:
    input_paths = {locations_input.resolve(), usage_input.resolve()}
    output_paths = {locations_output.resolve(), usage_output.resolve()}
    if len(output_paths) != 2 or input_paths & output_paths:
        raise ValueError("Input and output paths must all be different")

    location_rows, locations_by_name = read_locations(locations_input)
    usage_rows, linked_names, _ = read_usage(usage_input, locations_by_name)
    locations_temporary = prepare_output(
        locations_output, LOCATION_OUTPUT_FIELDS, location_rows
    )
    try:
        usage_temporary = prepare_output(
            usage_output, USAGE_OUTPUT_FIELDS, usage_rows
        )
    except Exception:
        locations_temporary.unlink(missing_ok=True)
        raise
    publish_outputs(
        [
            (locations_temporary, locations_output),
            (usage_temporary, usage_output),
        ]
    )

    missing_values = sum(not row["anzahl_clients"] for row in usage_rows)
    print(f"Wrote {len(location_rows):,} locations to {locations_output}")
    print(f"Wrote {len(usage_rows):,} monthly usage rows to {usage_output}")
    print(
        f"Linked {linked_names:,} of {EXPECTED_USAGE_LOCATION_COUNT:,} "
        "usage names to locations"
    )
    print(f"Preserved {missing_values:,} missing client counts")


def main() -> None:
    args = parse_args()
    convert(
        args.locations_input,
        args.usage_input,
        args.locations_output,
        args.usage_output,
    )


if __name__ == "__main__":
    main()
