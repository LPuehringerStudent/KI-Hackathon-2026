#!/usr/bin/env python3
"""Convert the official Linz fountain inventory into a web-friendly CSV."""

from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import os
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from coordinate_conversion import epsg31255_to_wgs84  # noqa: E402


SOURCE_FIELDS = [
    "Brunnennummer_ALT ",
    "Brunnennummer_Neu ",
    "Aufstellungsort",
    "Brunnenart",
    "Bauart",
    "Koordinaten_Brunnen_y",
    "Koordinaten_Brunnen_x",
    "In_Betrieb",
    "Trinkwasserbetrieb ",
    "Wasseranalyse",
    "Steuerung_Trinkbrunnen ",
    "Elektrik",
    "Pumpenart_Anzahl_Zeitsteuerung  ",
    "Beleuchtung",
    "Wassermenge_Sammelbecken ",
    "Lage_Brunnentechnik_W-Abpserrung  ",
    "Lage_Wasserzähler ",
    "Koordinaten_Wasserzähler_y",
    "Koordinaten_Wasserzähler_x",
    "Lage_E-Schaltschrank ",
    "Lage_Stromzäler ",
    "Bemerkung",
    "Betriebszeit",
    "für_Frostschutz_Wasserzähler_ausgebaut  ",
]
OUTPUT_FIELDS = [
    "id",
    "nummer_alt",
    "nummer_neu",
    "aufstellungsort",
    "brunnenart",
    "bauart",
    "epsg31255_x",
    "epsg31255_y",
    "lon",
    "lat",
    "in_betrieb",
    "trinkwasser",
    "wasseranalyse",
    "steuerung",
    "elektrik",
    "pumpe",
    "beleuchtung",
    "wassermenge_sammelbecken",
    "lage_brunnentechnik",
    "lage_wasserzaehler",
    "wasserzaehler_epsg31255_x",
    "wasserzaehler_epsg31255_y",
    "wasserzaehler_lon",
    "wasserzaehler_lat",
    "lage_e_schaltschrank",
    "lage_stromzaehler",
    "bemerkung",
    "betriebszeit",
    "frostschutz_wasserzaehler_ausgebaut",
]
NUMBER_PATTERN = re.compile(r"(?:TB|BmP|BoP)\d+")


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Convert the Linz fountain CSV.")
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=directory / "Trinkbrunnen-source.csv",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=directory / "Trinkbrunnen.csv",
    )
    return parser.parse_args()


def clean(value: str | None) -> str:
    return " ".join((value or "").split())


def boolean(value: str | None, *, field: str, line_number: int) -> str:
    normalized = clean(value).casefold()
    if not normalized:
        return ""
    if normalized not in {"ja", "nein"}:
        raise ValueError(
            f"Unexpected boolean in {field!r} on line {line_number}: {value!r}"
        )
    return "true" if normalized == "ja" else "false"


def coordinate_pair(
    easting_value: str | None,
    northing_value: str | None,
    *,
    line_number: int,
    field: str,
) -> tuple[str, str, str, str]:
    easting_text = clean(easting_value).replace(",", ".")
    northing_text = clean(northing_value).replace(",", ".")
    if not easting_text and not northing_text:
        return "", "", "", ""
    if not easting_text or not northing_text:
        raise ValueError(f"Incomplete {field} coordinate on line {line_number}")
    try:
        easting = Decimal(easting_text)
        northing = Decimal(northing_text)
    except InvalidOperation as error:
        raise ValueError(f"Invalid {field} coordinate on line {line_number}") from error
    if (
        not easting.is_finite()
        or not northing.is_finite()
        or not Decimal("60000") <= easting <= Decimal("90000")
        or not Decimal("330000") <= northing <= Decimal("370000")
    ):
        raise ValueError(f"Out-of-range {field} coordinate on line {line_number}")
    lon, lat = epsg31255_to_wgs84(float(easting), float(northing))
    return (
        format(easting.normalize(), "f"),
        format(northing.normalize(), "f"),
        f"{lon:.8f}",
        f"{lat:.8f}",
    )


def convert(input_path: Path, output_path: Path) -> None:
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must be different")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    seen_ids: set[str] = set()
    row_count = 0
    geocoded_count = 0
    converted_coordinate_count = 0

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
            reader = csv.DictReader(source, strict=True)
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
                old_number = clean(source_row["Brunnennummer_ALT "])
                new_number = clean(source_row["Brunnennummer_Neu "])
                identifier = new_number if NUMBER_PATTERN.fullmatch(new_number) else old_number
                if not identifier:
                    raise ValueError(f"Missing usable fountain number on line {line_number}")
                record_id = f"brunnen_{identifier.casefold()}"
                if record_id in seen_ids:
                    raise ValueError(f"Duplicate fountain ID on line {line_number}")
                seen_ids.add(record_id)

                # The source's *_y column contains the EPSG easting, while *_x
                # contains the northing. The output names the axes correctly.
                x, y, lon, lat = coordinate_pair(
                    source_row["Koordinaten_Brunnen_y"],
                    source_row["Koordinaten_Brunnen_x"],
                    line_number=line_number,
                    field="fountain",
                )
                meter_x, meter_y, meter_lon, meter_lat = coordinate_pair(
                    source_row["Koordinaten_Wasserzähler_y"],
                    source_row["Koordinaten_Wasserzähler_x"],
                    line_number=line_number,
                    field="water-meter",
                )
                geocoded_count += int(bool(lon))
                converted_coordinate_count += int(bool(lon)) + int(bool(meter_lon))
                writer.writerow(
                    {
                        "id": record_id,
                        "nummer_alt": old_number,
                        "nummer_neu": new_number,
                        "aufstellungsort": clean(source_row["Aufstellungsort"]),
                        "brunnenart": clean(source_row["Brunnenart"]),
                        "bauart": clean(source_row["Bauart"]),
                        "epsg31255_x": x,
                        "epsg31255_y": y,
                        "lon": lon,
                        "lat": lat,
                        "in_betrieb": boolean(
                            source_row["In_Betrieb"],
                            field="In_Betrieb",
                            line_number=line_number,
                        ),
                        "trinkwasser": boolean(
                            source_row["Trinkwasserbetrieb "],
                            field="Trinkwasserbetrieb",
                            line_number=line_number,
                        ),
                        "wasseranalyse": boolean(
                            source_row["Wasseranalyse"],
                            field="Wasseranalyse",
                            line_number=line_number,
                        ),
                        "steuerung": clean(source_row["Steuerung_Trinkbrunnen "]),
                        "elektrik": clean(source_row["Elektrik"]),
                        "pumpe": clean(
                            source_row["Pumpenart_Anzahl_Zeitsteuerung  "]
                        ),
                        "beleuchtung": clean(source_row["Beleuchtung"]),
                        "wassermenge_sammelbecken": clean(
                            source_row["Wassermenge_Sammelbecken "]
                        ),
                        "lage_brunnentechnik": clean(
                            source_row["Lage_Brunnentechnik_W-Abpserrung  "]
                        ),
                        "lage_wasserzaehler": clean(
                            source_row["Lage_Wasserzähler "]
                        ),
                        "wasserzaehler_epsg31255_x": meter_x,
                        "wasserzaehler_epsg31255_y": meter_y,
                        "wasserzaehler_lon": meter_lon,
                        "wasserzaehler_lat": meter_lat,
                        "lage_e_schaltschrank": clean(
                            source_row["Lage_E-Schaltschrank "]
                        ),
                        "lage_stromzaehler": clean(source_row["Lage_Stromzäler "]),
                        "bemerkung": clean(source_row["Bemerkung"]),
                        "betriebszeit": clean(source_row["Betriebszeit"]),
                        "frostschutz_wasserzaehler_ausgebaut": clean(
                            source_row[
                                "für_Frostschutz_Wasserzähler_ausgebaut  "
                            ]
                        ),
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

    print(f"Wrote {row_count:,} fountains to {output_path}")
    print(f"Generated {len(seen_ids):,} unique IDs")
    print(
        f"Converted {converted_coordinate_count:,} coordinate pairs to WGS84 "
        f"({geocoded_count:,} fountain, "
        f"{converted_coordinate_count - geocoded_count:,} water-meter)"
    )


def main() -> None:
    args = parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
