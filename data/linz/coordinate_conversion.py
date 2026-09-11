"""Small, dependency-free coordinate helpers for the Linz open-data converters."""

from __future__ import annotations

import math


# EPSG:31255: MGI / Austria GK Central
_BESSEL_A = 6_377_397.155
_BESSEL_INV_F = 299.1528128
_WGS84_A = 6_378_137.0
_WGS84_INV_F = 298.257223563
_CENTRAL_MERIDIAN = math.radians(13 + 20 / 60)


def _inverse_transverse_mercator(easting: float, northing: float) -> tuple[float, float]:
    flattening = 1 / _BESSEL_INV_F
    eccentricity_squared = flattening * (2 - flattening)
    second_eccentricity_squared = eccentricity_squared / (1 - eccentricity_squared)
    meridional_arc = northing + 5_000_000
    mu = meridional_arc / (
        _BESSEL_A
        * (
            1
            - eccentricity_squared / 4
            - 3 * eccentricity_squared**2 / 64
            - 5 * eccentricity_squared**3 / 256
        )
    )
    e1 = (1 - math.sqrt(1 - eccentricity_squared)) / (
        1 + math.sqrt(1 - eccentricity_squared)
    )
    footprint_latitude = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1**2 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + 151 * e1**3 / 96 * math.sin(6 * mu)
        + 1097 * e1**4 / 512 * math.sin(8 * mu)
    )
    sin_latitude = math.sin(footprint_latitude)
    cos_latitude = math.cos(footprint_latitude)
    tangent_squared = math.tan(footprint_latitude) ** 2
    c = second_eccentricity_squared * cos_latitude**2
    prime_vertical_radius = _BESSEL_A / math.sqrt(
        1 - eccentricity_squared * sin_latitude**2
    )
    meridional_radius = (
        _BESSEL_A
        * (1 - eccentricity_squared)
        / (1 - eccentricity_squared * sin_latitude**2) ** 1.5
    )
    d = easting / prime_vertical_radius

    latitude = footprint_latitude - (
        prime_vertical_radius
        * math.tan(footprint_latitude)
        / meridional_radius
        * (
            d**2 / 2
            - (
                5
                + 3 * tangent_squared
                + 10 * c
                - 4 * c**2
                - 9 * second_eccentricity_squared
            )
            * d**4
            / 24
            + (
                61
                + 90 * tangent_squared
                + 298 * c
                + 45 * tangent_squared**2
                - 252 * second_eccentricity_squared
                - 3 * c**2
            )
            * d**6
            / 720
        )
    )
    longitude = _CENTRAL_MERIDIAN + (
        d
        - (1 + 2 * tangent_squared + c) * d**3 / 6
        + (
            5
            - 2 * c
            + 28 * tangent_squared
            - 3 * c**2
            + 8 * second_eccentricity_squared
            + 24 * tangent_squared**2
        )
        * d**5
        / 120
    ) / cos_latitude
    return latitude, longitude


def _to_cartesian(
    latitude: float, longitude: float, semi_major_axis: float, inverse_flattening: float
) -> tuple[float, float, float]:
    flattening = 1 / inverse_flattening
    eccentricity_squared = flattening * (2 - flattening)
    radius = semi_major_axis / math.sqrt(
        1 - eccentricity_squared * math.sin(latitude) ** 2
    )
    return (
        radius * math.cos(latitude) * math.cos(longitude),
        radius * math.cos(latitude) * math.sin(longitude),
        radius * (1 - eccentricity_squared) * math.sin(latitude),
    )


def _to_geodetic(
    x: float, y: float, z: float, semi_major_axis: float, inverse_flattening: float
) -> tuple[float, float]:
    flattening = 1 / inverse_flattening
    eccentricity_squared = flattening * (2 - flattening)
    longitude = math.atan2(y, x)
    horizontal = math.hypot(x, y)
    latitude = math.atan2(z, horizontal * (1 - eccentricity_squared))
    for _ in range(10):
        radius = semi_major_axis / math.sqrt(
            1 - eccentricity_squared * math.sin(latitude) ** 2
        )
        latitude = math.atan2(
            z + eccentricity_squared * radius * math.sin(latitude), horizontal
        )
    return latitude, longitude


def epsg31255_to_wgs84(easting: float, northing: float) -> tuple[float, float]:
    """Return ``(longitude, latitude)`` for an EPSG:31255 point."""
    if not (math.isfinite(easting) and math.isfinite(northing)):
        raise ValueError("Coordinates must be finite")

    latitude, longitude = _inverse_transverse_mercator(easting, northing)
    x, y, z = _to_cartesian(
        latitude, longitude, _BESSEL_A, _BESSEL_INV_F
    )

    # EPSG transformation 1618, expressed as PROJ's position-vector
    # +towgs84 parameters (metres, arc-seconds, parts per million).
    dx, dy, dz = 577.326, 90.129, 463.919
    rx, ry, rz = (
        math.radians(value / 3600) for value in (5.137, 1.474, 5.297)
    )
    scale = 1 + 2.4232e-6
    transformed_x = dx + scale * x - rz * y + ry * z
    transformed_y = dy + rz * x + scale * y - rx * z
    transformed_z = dz - ry * x + rx * y + scale * z

    latitude, longitude = _to_geodetic(
        transformed_x,
        transformed_y,
        transformed_z,
        _WGS84_A,
        _WGS84_INV_F,
    )
    return math.degrees(longitude), math.degrees(latitude)
