#!/usr/bin/env python3
"""Build one student-friendly JSON snapshot from the Linztermine XML feeds."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import html
import json
import os
from pathlib import Path
import tempfile
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo


BASE_URL = "https://www.linztermine.at/schnittstelle/downloads"
SOURCE_URLS = {
    "events": f"{BASE_URL}/events_xml.php",
    "locations": f"{BASE_URL}/locations_xml.php",
    "organizers": f"{BASE_URL}/organizers_xml.php",
    "tags": f"{BASE_URL}/tags_xml.php",
}
DEFAULT_DATE_FROM = "2026-09-05 00:00:00"
DEFAULT_DATE_UNTIL = "2026-09-14 23:59:59"
LINZ_TIMEZONE = ZoneInfo("Europe/Vienna")


def parse_args() -> argparse.Namespace:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Combine the four live Linztermine XML feeds into one JSON file."
    )
    parser.add_argument("--date-from", default=DEFAULT_DATE_FROM)
    parser.add_argument("--date-until", default=DEFAULT_DATE_UNTIL)
    parser.add_argument(
        "--output",
        type=Path,
        default=directory / "Linztermine.json",
        help="prepared output JSON (default: %(default)s)",
    )
    parser.add_argument(
        "--events-input",
        type=Path,
        help="optional local events XML instead of a live download",
    )
    parser.add_argument(
        "--locations-input",
        type=Path,
        help="optional local locations XML instead of a live download",
    )
    parser.add_argument(
        "--organizers-input",
        type=Path,
        help="optional local organizers XML instead of a live download",
    )
    parser.add_argument(
        "--tags-input",
        type=Path,
        help="optional local tags XML instead of a live download",
    )
    parser.add_argument(
        "--retrieved-at",
        help=(
            "timezone-aware ISO timestamp; required with local XML inputs "
            "(live builds use the event response's HTTP Date header)"
        ),
    )
    return parser.parse_args()


def clean_text(value: str | None) -> str:
    return " ".join(html.unescape(value or "").split())


def element_text(element: ET.Element | None) -> str:
    if element is None:
        return ""
    return clean_text("".join(element.itertext()))


def linz_datetime(value: str | None, *, context: str) -> datetime:
    normalized = clean_text(value)
    if not normalized:
        raise ValueError(f"Missing Linztermine datetime in {context}")
    try:
        parsed = datetime.strptime(normalized, "%Y-%m-%d %H:%M:%S")
    except ValueError as error:
        raise ValueError(
            f"Invalid Linztermine datetime in {context}: {normalized!r}"
        ) from error
    return parsed.replace(tzinfo=LINZ_TIMEZONE)


def iso_datetime(value: str | None, *, context: str) -> str:
    return linz_datetime(value, context=context).isoformat()


def iso_retrieved_at(value: str) -> str:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"Invalid --retrieved-at timestamp: {value!r}") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("--retrieved-at must include a timezone offset")
    return parsed.isoformat(timespec="seconds")


def source_bool(
    value: str | None, *, field: str, event_id: str
) -> bool | None:
    if value in {None, ""}:
        return None
    if value not in {"0", "1"}:
        raise ValueError(
            f"Unexpected {field} value for event {event_id}: {value!r}"
        )
    return value == "1"


def download(url: str) -> tuple[bytes, str]:
    request = Request(url, headers={"User-Agent": "ars-hackathon-data-preparer/1.0"})
    with urlopen(request, timeout=60) as response:
        response_date = response.headers.get("Date")
        if not response_date:
            raise ValueError(f"Live response does not include an HTTP Date: {url}")
        return (
            response.read(),
            parsedate_to_datetime(response_date).astimezone(timezone.utc).isoformat(
                timespec="seconds"
            ),
        )


def read_source(path: Path | None, url: str) -> tuple[bytes, str | None]:
    return (path.read_bytes(), None) if path else download(url)


def validate_element(
    element: ET.Element,
    *,
    context: str,
    attributes: set[str],
    children: dict[str, tuple[int, int | None]],
) -> None:
    """Reject unknown/missing XML attributes, children, and multiplicity drift."""
    received_attributes = set(element.attrib)
    if received_attributes != attributes:
        raise ValueError(
            f"Unexpected attributes in {context}. Expected {sorted(attributes)}, "
            f"received {sorted(received_attributes)}"
        )
    counts = Counter(child.tag for child in element)
    unknown_children = set(counts) - set(children)
    if unknown_children:
        raise ValueError(
            f"Unexpected fields in {context}: {sorted(unknown_children)}"
        )
    for tag, (minimum, maximum) in children.items():
        count = counts[tag]
        if count < minimum or (maximum is not None and count > maximum):
            expected = f"{minimum}+" if maximum is None else f"{minimum}..{maximum}"
            raise ValueError(
                f"Unexpected {tag!r} count in {context}: expected {expected}, "
                f"received {count}"
            )


def validate_leaf(
    element: ET.Element, *, context: str, attributes: set[str] | None = None
) -> None:
    validate_element(
        element,
        context=context,
        attributes=attributes or set(),
        children={},
    )


def parse_xml(payload: bytes, *, expected_root: str, source_name: str) -> ET.Element:
    # events_xml.php declares ISO-8859-1 but currently sends UTF-8 bytes. Decode
    # according to the HTTP payload reality before parsing the XML declaration.
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise ValueError(f"{source_name} is not valid UTF-8") from error
    try:
        root = ET.fromstring(text)
    except ET.ParseError as error:
        raise ValueError(f"{source_name} is not well-formed XML") from error
    if root.tag != expected_root:
        raise ValueError(
            f"Unexpected {source_name} root: expected {expected_root!r}, "
            f"received {root.tag!r}"
        )
    return root


def require_unique_ids(rows: list[dict[str, object]], *, source_name: str) -> None:
    ids = [str(row["id"]) for row in rows]
    if any(not record_id for record_id in ids):
        raise ValueError(f"{source_name} contains an empty ID")
    if len(ids) != len(set(ids)):
        raise ValueError(f"{source_name} contains duplicate IDs")


def parse_locations(root: ET.Element) -> list[dict[str, object]]:
    validate_element(
        root,
        context="location root",
        attributes=set(),
        children={"location": (0, None), "site": (0, None)},
    )
    rows: list[dict[str, object]] = []
    for element in root:
        fields = {
            "name",
            "street",
            "postcode",
            "city",
            "state",
            "telephone",
            "description",
            "link",
        }
        if element.tag == "site":
            fields.add("subof")
        validate_element(
            element,
            context=f"{element.tag} {element.get('id')!r}",
            attributes={"id"},
            children={field: (1, 1) for field in fields},
        )
        for child in element:
            validate_leaf(child, context=f"{element.tag}/{child.tag}")
        rows.append(
            {
                "id": clean_text(element.get("id")),
                "type": "ort" if element.tag == "location" else "unterort",
                "parent_id": clean_text(element.findtext("subof")),
                "name": clean_text(element.findtext("name")),
                "street": clean_text(element.findtext("street")),
                "postcode": clean_text(element.findtext("postcode")),
                "city": clean_text(element.findtext("city")),
                "country": clean_text(element.findtext("state")),
                "telephone": clean_text(element.findtext("telephone")),
                "description": clean_text(element.findtext("description")),
                "url": clean_text(element.findtext("link")),
            }
        )
    require_unique_ids(rows, source_name="locations")
    return rows


def parse_organizers(root: ET.Element) -> list[dict[str, object]]:
    validate_element(
        root,
        context="organizer root",
        attributes=set(),
        children={"organizer": (0, None)},
    )
    rows: list[dict[str, object]] = []
    for element in root:
        fields = {"name", "street", "postcode", "city", "state", "telephone", "link"}
        validate_element(
            element,
            context=f"organizer {element.get('id')!r}",
            attributes={"id"},
            children={field: (1, 1) for field in fields},
        )
        for child in element:
            validate_leaf(child, context=f"organizer/{child.tag}")
        rows.append(
            {
                "id": clean_text(element.get("id")),
                "name": clean_text(element.findtext("name")),
                "street": clean_text(element.findtext("street")),
                "postcode": clean_text(element.findtext("postcode")),
                "city": clean_text(element.findtext("city")),
                "country": clean_text(element.findtext("state")),
                "telephone": clean_text(element.findtext("telephone")),
                "url": clean_text(element.findtext("link")),
            }
        )
    require_unique_ids(rows, source_name="organizers")
    return rows


def parse_tags(root: ET.Element) -> list[dict[str, object]]:
    validate_element(
        root,
        context="tag root",
        attributes=set(),
        children={"tag": (0, None)},
    )
    rows: list[dict[str, object]] = []
    for tag in root:
        validate_element(
            tag,
            context=f"tag {tag.get('id')!r}",
            attributes={"id", "name"},
            children={"subtag": (0, None)},
        )
        tag_id = clean_text(tag.get("id"))
        rows.append(
            {
                "id": tag_id,
                "name": clean_text(tag.get("name")),
                "parent_id": "",
            }
        )
        for subtag in tag:
            validate_leaf(
                subtag,
                context=f"subtag {subtag.get('id')!r}",
                attributes={"id", "name"},
            )
            rows.append(
                {
                    "id": clean_text(subtag.get("id")),
                    "name": clean_text(subtag.get("name")),
                    "parent_id": tag_id,
                }
            )
    require_unique_ids(rows, source_name="tags")
    return rows


def parse_links(parent: ET.Element, *, event_id: str) -> list[dict[str, str]]:
    validate_element(
        parent,
        context=f"links for event {event_id}",
        attributes=set(),
        children={"link": (0, None)},
    )
    for link in parent:
        validate_element(
            link,
            context=f"link for event {event_id}",
            attributes=set(),
            children={"url": (1, 1), "info": (1, 1)},
        )
        for child in link:
            validate_leaf(child, context=f"link/{child.tag} for event {event_id}")
    return [
        {
            "url": clean_text(link.findtext("url")),
            "label": clean_text(link.findtext("info")),
        }
        for link in parent.findall("./link")
        if clean_text(link.findtext("url"))
    ]


def parse_events(root: ET.Element) -> list[dict[str, object]]:
    validate_element(
        root,
        context="event root",
        attributes=set(),
        children={"event": (0, None)},
    )
    rows: list[dict[str, object]] = []
    for element in root:
        event_id = clean_text(element.get("id"))
        validate_element(
            element,
            context=f"event {event_id!r}",
            attributes={
                "id",
                "firstdate",
                "lastdate",
                "properforchildren",
                "freeofcharge",
                "roottag",
            },
            children={
                "title": (1, 1),
                "description": (1, 1),
                "organizer": (1, 1),
                "location": (1, 1),
                "tags": (0, 1),
                "categories": (0, 1),
                "links": (1, 1),
                "locationdescription": (0, 1),
                "date": (1, None),
            },
        )
        location = element.find("./location")
        organizer = element.find("./organizer")
        for field in ("title", "description", "locationdescription"):
            child = element.find(f"./{field}")
            if child is not None:
                validate_leaf(child, context=f"event {event_id}/{field}")
        assert location is not None and organizer is not None
        validate_leaf(
            location,
            context=f"event {event_id}/location",
            attributes={"id"},
        )
        validate_element(
            organizer,
            context=f"event {event_id}/organizer",
            attributes={"id"},
            children={"link": (1, 1)},
        )
        organizer_link = organizer.find("./link")
        assert organizer_link is not None
        validate_element(
            organizer_link,
            context=f"event {event_id}/organizer/link",
            attributes=set(),
            children={"url": (1, 1)},
        )
        organizer_url = organizer_link.find("./url")
        assert organizer_url is not None
        validate_leaf(organizer_url, context=f"event {event_id}/organizer/link/url")

        tags_parent = element.find("./tags")
        tag_ids_for_event: list[str] = []
        if tags_parent is not None:
            validate_element(
                tags_parent,
                context=f"event {event_id}/tags",
                attributes=set(),
                children={"tag": (1, None)},
            )
            for tag in tags_parent:
                validate_leaf(
                    tag,
                    context=f"event {event_id}/tags/tag",
                    attributes={"id"},
                )
                tag_ids_for_event.append(clean_text(tag.get("id")))
            if len(tag_ids_for_event) != len(set(tag_ids_for_event)):
                raise ValueError(f"Event {event_id} contains duplicate tag IDs")

        categories = element.find("./categories")
        if categories is not None:
            validate_element(
                categories,
                context=f"event {event_id}/categories",
                attributes=set(),
                children={"category": (1, None)},
            )
            for category in categories:
                validate_leaf(
                    category,
                    context=f"event {event_id}/categories/category",
                    attributes={"id"},
                )

        occurrences = []
        for occurrence_index, date in enumerate(element.findall("./date"), start=1):
            validate_leaf(
                date,
                context=f"event {event_id}/date {occurrence_index}",
                attributes={"dFrom", "dTo"},
            )
            start = linz_datetime(
                date.get("dFrom"), context=f"event {event_id} occurrence start"
            )
            end = linz_datetime(
                date.get("dTo"), context=f"event {event_id} occurrence end"
            )
            if end < start:
                raise ValueError(
                    f"Event {event_id} occurrence {occurrence_index} ends before it starts"
                )
            occurrences.append({"start": start.isoformat(), "end": end.isoformat()})

        first_date = linz_datetime(
            element.get("firstdate"), context=f"event {event_id} firstdate"
        )
        last_date = linz_datetime(
            element.get("lastdate"), context=f"event {event_id} lastdate"
        )
        if last_date < first_date:
            raise ValueError(f"Event {event_id} lastdate precedes firstdate")

        rows.append(
            {
                "id": event_id,
                "title": element_text(element.find("./title")),
                "description": element_text(element.find("./description")),
                "first_date": first_date.isoformat(),
                "last_date": last_date.isoformat(),
                "suitable_for_children": source_bool(
                    element.get("properforchildren"),
                    field="properforchildren",
                    event_id=event_id,
                ),
                "free_of_charge": source_bool(
                    element.get("freeofcharge"),
                    field="freeofcharge",
                    event_id=event_id,
                ),
                "root_tag_id": clean_text(element.get("roottag")),
                "tag_ids": tag_ids_for_event,
                "location_id": clean_text(
                    location.get("id") if location is not None else ""
                ),
                "location_name": element_text(location),
                "location_description": element_text(
                    element.find("./locationdescription")
                ),
                "organizer_id": clean_text(
                    organizer.get("id") if organizer is not None else ""
                ),
                "organizer_name": clean_text(
                    organizer.text if organizer is not None else ""
                ),
                "links": parse_links(element.find("./links"), event_id=event_id),  # type: ignore[arg-type]
                "occurrences": occurrences,
            }
        )
    require_unique_ids(rows, source_name="events")
    rows.sort(
        key=lambda row: (
            str(row["occurrences"][0]["start"]),  # type: ignore[index]
            str(row["title"]),
            str(row["id"]),
        )
    )
    return rows


def build_snapshot(
    *,
    event_payload: bytes,
    location_payload: bytes,
    organizer_payload: bytes,
    tag_payload: bytes,
    date_from: str,
    date_until: str,
    retrieved_at: str,
) -> dict[str, object]:
    events = parse_events(
        parse_xml(event_payload, expected_root="events", source_name="events")
    )
    locations = parse_locations(
        parse_xml(
            location_payload, expected_root="loclist", source_name="locations"
        )
    )
    organizers = parse_organizers(
        parse_xml(
            organizer_payload, expected_root="organizers", source_name="organizers"
        )
    )
    tags = parse_tags(
        parse_xml(tag_payload, expected_root="taglist", source_name="tags")
    )

    location_ids = {str(row["id"]) for row in locations}
    organizer_ids = {str(row["id"]) for row in organizers}
    tag_ids = {str(row["id"]) for row in tags}
    unresolved_locations = sum(
        str(event["location_id"]) not in location_ids for event in events
    )
    unresolved_organizers = sum(
        str(event["organizer_id"]) not in organizer_ids for event in events
    )
    unresolved_tags = sum(
        tag_id not in tag_ids
        for event in events
        for tag_id in event["tag_ids"]  # type: ignore[union-attr]
    )
    unresolved_root_tags = sum(
        str(event["root_tag_id"]) not in tag_ids for event in events
    )
    occurrence_count = sum(
        len(event["occurrences"]) for event in events  # type: ignore[arg-type]
    )

    return {
        "_meta": {
            "retrieved_at": retrieved_at,
            "event_window": {
                "from": iso_datetime(date_from, context="event window start"),
                "until": iso_datetime(date_until, context="event window end"),
            },
            "license": "CC BY 4.0",
            "source_urls": SOURCE_URLS,
            "record_counts": {
                "events": len(events),
                "occurrences": occurrence_count,
                "locations": len(locations),
                "organizers": len(organizers),
                "tags": len(tags),
            },
            "quality": {
                "unresolved_event_location_ids": unresolved_locations,
                "unresolved_event_organizer_ids": unresolved_organizers,
                "unresolved_event_tag_ids": unresolved_tags,
                "unresolved_event_root_tag_ids": unresolved_root_tags,
                "events_without_description": sum(
                    not event["description"] for event in events
                ),
                "events_with_unknown_children_flag": sum(
                    event["suitable_for_children"] is None for event in events
                ),
                "events_with_unknown_free_flag": sum(
                    event["free_of_charge"] is None for event in events
                ),
            },
        },
        "events": events,
        "locations": locations,
        "organizers": organizers,
        "tags": tags,
    }


def write_json(output_path: Path, snapshot: dict[str, object]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        temporary_path = Path(temporary.name)
        try:
            json.dump(
                snapshot,
                temporary,
                ensure_ascii=False,
                indent=2,
                sort_keys=False,
            )
            temporary.write("\n")
            temporary.flush()
            os.fsync(temporary.fileno())
            os.chmod(temporary_path, 0o644)
            os.replace(temporary_path, output_path)
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise


def main() -> None:
    args = parse_args()
    local_inputs = [
        path
        for path in (
            args.events_input,
            args.locations_input,
            args.organizers_input,
            args.tags_input,
        )
        if path is not None
    ]
    if any(path.resolve() == args.output.resolve() for path in local_inputs):
        raise ValueError("Input and output paths must be different")
    if local_inputs and not args.retrieved_at:
        raise ValueError("--retrieved-at is required when local XML inputs are used")
    query = urlencode(
        {
            "lt_datefrom": args.date_from,
            "lt_dateuntil": args.date_until,
        }
    )
    event_url = f"{SOURCE_URLS['events']}?{query}"
    sources = {
        "events": read_source(args.events_input, event_url),
        "locations": read_source(args.locations_input, SOURCE_URLS["locations"]),
        "organizers": read_source(
            args.organizers_input, SOURCE_URLS["organizers"]
        ),
        "tags": read_source(args.tags_input, SOURCE_URLS["tags"]),
    }
    inputs = {name: value[0] for name, value in sources.items()}
    retrieved_at = iso_retrieved_at(
        args.retrieved_at or sources["events"][1] or ""
    )
    snapshot = build_snapshot(
        event_payload=inputs["events"],
        location_payload=inputs["locations"],
        organizer_payload=inputs["organizers"],
        tag_payload=inputs["tags"],
        date_from=args.date_from,
        date_until=args.date_until,
        retrieved_at=retrieved_at,
    )
    write_json(args.output, snapshot)
    counts = snapshot["_meta"]["record_counts"]  # type: ignore[index]
    quality = snapshot["_meta"]["quality"]  # type: ignore[index]
    print(f"Wrote {counts['events']:,} events to {args.output}")
    print(f"Expanded {counts['occurrences']:,} event occurrences")
    print(
        f"Included {counts['locations']:,} locations, "
        f"{counts['organizers']:,} organizers, and {counts['tags']:,} tags"
    )
    print(
        "Preserved "
        f"{quality['unresolved_event_location_ids']:,} unresolved location "
        "references reported by the live feeds"
    )


if __name__ == "__main__":
    main()
