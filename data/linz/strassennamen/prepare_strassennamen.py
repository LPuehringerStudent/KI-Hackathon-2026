#!/usr/bin/env python3
"""Convert both official Linz street-name exports into tidy UTF-8 CSV files."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import tempfile


CURRENT_SOURCE_FIELDS = [
    "ID",
    "Name",
    "KG",
    "Beschreibung",
    "Link",
    "Wikidata ID",
    "Wikidata Link",
    "Benannt nach",
    "Wikidata Person ID",
    "Wikidata Person Link",
    "Wikidata Person Name",
    "Wikidata Person Geschlecht",
    "Wikidata Person Beruf",
    "Wikidata Person Geburtsdatum",
    "Wikidata Person Sterbedatum",
]
HISTORICAL_SOURCE_FIELDS = [
    "ID",
    "Name",
    "KG",
    "Beschreibung",
    "Link",
    "Benannt nach",
    "Wikidata",
    "Wikidata Link",
    "Wikidata Name",
    "Wikidata Geschlecht",
    "Wikidata Beruf",
    "Wikidata Geburtsdatum",
    "Wikidata Sterbedatum",
    "Aktuelle Straße",
    "m/w",
    "Jahr der Benennung",
    "Jahr der Löschung",
]
CURRENT_OUTPUT_FIELDS = [
    "id",
    "quell_id",
    "name",
    "katastralgemeinde",
    "beschreibung",
    "detail_url",
    "strasse_wikidata_id",
    "strasse_wikidata_url",
    "benannt_nach",
    "person_wikidata_id",
    "weitere_person_wikidata_ids",
    "person_wikidata_url",
    "person_name",
    "person_geschlecht",
    "person_beruf",
    "person_geburtsdatum",
    "person_sterbedatum",
]
HISTORICAL_OUTPUT_FIELDS = [
    "id",
    "quell_id",
    "name",
    "katastralgemeinde",
    "beschreibung",
    "detail_url",
    "benannt_nach",
    "person_wikidata_id",
    "weitere_person_wikidata_ids",
    "person_wikidata_url",
    "person_name",
    "person_geschlecht",
    "person_beruf",
    "person_geburtsdatum",
    "person_sterbedatum",
    "heutiger_strassenname",
    "benennung_code",
    "jahr_benennung",
    "jahr_loeschung",
]
WIKIDATA_ID_PATTERN = re.compile(r"Q[1-9][0-9]*")


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Convert both Linz street-name CSVs.")
    parser.add_argument(
        "--current-input",
        type=Path,
        default=directory / "Strassennamen-aktuell-source.csv",
    )
    parser.add_argument(
        "--historical-input",
        type=Path,
        default=directory / "Strassennamen-historisch-source.csv",
    )
    parser.add_argument(
        "--current-output",
        type=Path,
        default=directory / "Strassennamen-aktuell.csv",
    )
    parser.add_argument(
        "--historical-output",
        type=Path,
        default=directory / "Strassennamen-historisch.csv",
    )
    return parser.parse_args()


def clean(value: str | None) -> str:
    return " ".join((value or "").split())


def date_only(value: str | None, *, line_number: int, field: str) -> str:
    normalized = clean(value)
    if not normalized:
        return ""
    try:
        return datetime.strptime(normalized, "%Y-%m-%dT%H:%M:%SZ").date().isoformat()
    except ValueError as error:
        raise ValueError(
            f"Invalid date in {field!r} on line {line_number}: {value!r}"
        ) from error


def wikidata_person(
    identifier_value: str | None,
    url_value: str | None,
    *,
    line_number: int,
) -> tuple[str, str, str]:
    """Return one primary ID, any additional IDs, and a canonical URL."""
    identifiers = [part.strip() for part in clean(identifier_value).split(",")]
    identifiers = [identifier for identifier in identifiers if identifier]
    if any(
        not WIKIDATA_ID_PATTERN.fullmatch(identifier) for identifier in identifiers
    ):
        raise ValueError(
            f"Invalid Wikidata person ID on line {line_number}: {identifier_value!r}"
        )
    if len(identifiers) != len(set(identifiers)):
        raise ValueError(f"Duplicate Wikidata person ID on line {line_number}")

    source_url = clean(url_value)
    if not identifiers:
        if source_url:
            raise ValueError(
                f"Wikidata person URL without an ID on line {line_number}: "
                f"{source_url!r}"
            )
        return "", "", ""

    primary_id = identifiers[0]
    canonical_url = f"https://www.wikidata.org/wiki/{primary_id}"
    if (
        source_url.startswith("https://www.wikidata.org/wiki/")
        and source_url != canonical_url
    ):
        raise ValueError(
            f"Mismatched Wikidata person URL on line {line_number}: {source_url!r}"
        )
    return primary_id, "|".join(identifiers[1:]), canonical_url


def validate_row(
    row: dict[str | None, str | None],
    fields: list[str],
    *,
    line_number: int,
) -> None:
    if None in row:
        raise ValueError(f"Unexpected extra column on line {line_number}")
    if any(row[field] is None for field in fields):
        raise ValueError(f"Missing column value on line {line_number}")


def read_rows(
    path: Path, expected_fields: list[str]
) -> list[tuple[int, dict[str | None, str | None]]]:
    with path.open(encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source, strict=True)
        if reader.fieldnames != expected_fields:
            raise ValueError(
                f"Unexpected columns in {path.name}.\n"
                f"Expected: {expected_fields}\nReceived: {reader.fieldnames}"
            )
        result = []
        for line_number, row in enumerate(reader, start=2):
            validate_row(row, expected_fields, line_number=line_number)
            result.append((line_number, row))
        return result


def prepare_output(
    path: Path, fields: list[str], rows: list[dict[str, str]]
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        newline="",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
        try:
            writer = csv.DictWriter(
                temporary, fieldnames=fields, lineterminator="\n"
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


def convert_current(path: Path) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    for line_number, source in read_rows(path, CURRENT_SOURCE_FIELDS):
        source_id = clean(source["ID"])
        name = clean(source["Name"])
        if not source_id.isdecimal() or not name:
            raise ValueError(f"Invalid ID or name on line {line_number}")
        record_id = f"strasse_{source_id}"
        if record_id in seen_ids:
            raise ValueError(f"Duplicate ID on line {line_number}: {record_id}")
        seen_ids.add(record_id)
        person_id, additional_person_ids, person_url = wikidata_person(
            source["Wikidata Person ID"],
            source["Wikidata Person Link"],
            line_number=line_number,
        )
        street_id, additional_street_ids, street_url = wikidata_person(
            source["Wikidata ID"],
            source["Wikidata Link"],
            line_number=line_number,
        )
        if additional_street_ids:
            raise ValueError(
                f"Multiple Wikidata street IDs on line {line_number}: "
                f"{source['Wikidata ID']!r}"
            )
        output.append(
            {
                "id": record_id,
                "quell_id": source_id,
                "name": name,
                "katastralgemeinde": clean(source["KG"]),
                "beschreibung": clean(source["Beschreibung"]),
                "detail_url": clean(source["Link"]).replace("http://", "https://", 1),
                "strasse_wikidata_id": street_id,
                "strasse_wikidata_url": street_url,
                "benannt_nach": clean(source["Benannt nach"]),
                "person_wikidata_id": person_id,
                "weitere_person_wikidata_ids": additional_person_ids,
                "person_wikidata_url": person_url,
                "person_name": clean(source["Wikidata Person Name"]),
                "person_geschlecht": clean(source["Wikidata Person Geschlecht"]),
                "person_beruf": clean(source["Wikidata Person Beruf"]),
                "person_geburtsdatum": date_only(
                    source["Wikidata Person Geburtsdatum"],
                    line_number=line_number,
                    field="Wikidata Person Geburtsdatum",
                ),
                "person_sterbedatum": date_only(
                    source["Wikidata Person Sterbedatum"],
                    line_number=line_number,
                    field="Wikidata Person Sterbedatum",
                ),
            }
        )
    return output


def convert_historical(path: Path) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    for line_number, source in read_rows(path, HISTORICAL_SOURCE_FIELDS):
        source_id = clean(source["ID"])
        name = clean(source["Name"])
        code = clean(source["m/w"])
        if not source_id.isdecimal() or not name:
            raise ValueError(f"Invalid ID or name on line {line_number}")
        if code not in {"", "M", "W", "X"}:
            raise ValueError(f"Unexpected m/w code on line {line_number}: {code!r}")
        record_id = f"strasse_historisch_{source_id}"
        if record_id in seen_ids:
            raise ValueError(f"Duplicate ID on line {line_number}: {record_id}")
        seen_ids.add(record_id)
        person_id, additional_person_ids, person_url = wikidata_person(
            source["Wikidata"],
            source["Wikidata Link"],
            line_number=line_number,
        )
        output.append(
            {
                "id": record_id,
                "quell_id": source_id,
                "name": name,
                "katastralgemeinde": clean(source["KG"]),
                "beschreibung": clean(source["Beschreibung"]),
                "detail_url": clean(source["Link"]),
                "benannt_nach": clean(source["Benannt nach"]),
                "person_wikidata_id": person_id,
                "weitere_person_wikidata_ids": additional_person_ids,
                "person_wikidata_url": person_url,
                "person_name": clean(source["Wikidata Name"]),
                "person_geschlecht": clean(source["Wikidata Geschlecht"]),
                "person_beruf": clean(source["Wikidata Beruf"]),
                "person_geburtsdatum": date_only(
                    source["Wikidata Geburtsdatum"],
                    line_number=line_number,
                    field="Wikidata Geburtsdatum",
                ),
                "person_sterbedatum": date_only(
                    source["Wikidata Sterbedatum"],
                    line_number=line_number,
                    field="Wikidata Sterbedatum",
                ),
                "heutiger_strassenname": clean(source["Aktuelle Straße"]),
                "benennung_code": code,
                "jahr_benennung": clean(source["Jahr der Benennung"]),
                "jahr_loeschung": clean(source["Jahr der Löschung"]),
            }
        )
    return output


def main() -> None:
    args = parse_args()
    input_paths = {args.current_input.resolve(), args.historical_input.resolve()}
    output_paths = {args.current_output.resolve(), args.historical_output.resolve()}
    if len(input_paths) != 2 or len(output_paths) != 2 or input_paths & output_paths:
        raise ValueError("Input and output paths must all be different")
    current = convert_current(args.current_input)
    historical = convert_historical(args.historical_input)
    current_temporary = prepare_output(
        args.current_output, CURRENT_OUTPUT_FIELDS, current
    )
    try:
        historical_temporary = prepare_output(
            args.historical_output, HISTORICAL_OUTPUT_FIELDS, historical
        )
    except Exception:
        current_temporary.unlink(missing_ok=True)
        raise
    publish_outputs(
        [
            (current_temporary, args.current_output),
            (historical_temporary, args.historical_output),
        ]
    )
    print(f"Wrote {len(current):,} current streets to {args.current_output}")
    print(f"Wrote {len(historical):,} historical streets to {args.historical_output}")


if __name__ == "__main__":
    main()
