from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


BG = (255, 255, 255)
RIM = (18, 90, 191)
RIM_LIGHT = (35, 137, 255)
FACE = (237, 245, 255)
KNOB = (12, 68, 164)
BUTTON = (15, 102, 225)
HAND = (9, 62, 155)
ACCENT = (45, 156, 255)


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def _clamp_color(c: tuple[int, int, int]) -> tuple[int, int, int]:
    return tuple(min(255, max(0, v)) for v in c)


def _render_icon(size: int) -> list[bytes]:
    cx = size / 2
    cy = size * 0.55
    radius = size * 0.38
    rim_width = size * 0.055
    face_radius = radius - rim_width

    knob_width = size * 0.23
    knob_height = size * 0.08
    knob_gap = size * 0.02

    button_width = size * 0.12
    button_height = size * 0.07
    button_gap = size * 0.015
    button_y = cy - radius * 0.35

    center_radius = size * 0.035

    def _in_rect(px: float, py: float, x0: float, x1: float, y0: float, y1: float) -> bool:
        return x0 <= px <= x1 and y0 <= py <= y1

    def _on_hand(dx: float, dy: float, angle: float, length: float, thickness: float) -> bool:
        ux = math.cos(angle)
        uy = math.sin(angle)
        proj = dx * ux + dy * uy
        if proj < 0 or proj > length:
            return False
        perp = abs(dx * uy - dy * ux)
        return perp <= thickness / 2

    rows: list[bytes] = []
    for y in range(size):
        row = bytearray()
        py = y + 0.5
        for x in range(size):
            px = x + 0.5
            color = BG

            dx = px - cx
            dy = py - cy
            dist = math.hypot(dx, dy)

            if dist <= radius:
                if dist >= face_radius:
                    rim_t = (dist - face_radius) / max(rim_width, 1e-3)
                    color = _mix(RIM, RIM_LIGHT, min(1.0, rim_t * 0.8))
                else:
                    color = FACE

                # subtle highlight at top-left
                if dist <= face_radius * 0.95 and dx + dy < 0 and dy < 0:
                    highlight = _mix(color, BG, 0.15)
                    color = _clamp_color(highlight)

            # buttons and knob overlay
            if _in_rect(
                px,
                py,
                cx - knob_width / 2,
                cx + knob_width / 2,
                cy - radius - knob_gap - knob_height,
                cy - radius - knob_gap,
            ):
                color = KNOB
            if _in_rect(
                px,
                py,
                cx - radius - button_gap - button_width,
                cx - radius - button_gap,
                button_y - button_height / 2,
                button_y + button_height / 2,
            ):
                color = KNOB
            if _in_rect(
                px,
                py,
                cx + radius + button_gap,
                cx + radius + button_gap + button_width,
                button_y - button_height / 2,
                button_y + button_height / 2,
            ):
                color = KNOB

            # hands
            if dist <= face_radius:
                if _on_hand(dx, dy, -math.pi / 2.5, radius * 0.72, size * 0.025):
                    color = HAND
                if _on_hand(dx, dy, math.pi * 0.75, radius * 0.5, size * 0.02):
                    color = HAND
                if _on_hand(dx, dy, -math.pi / 12, radius * 0.85, size * 0.015):
                    color = ACCENT

            if dist <= center_radius:
                color = HAND

            row.extend(color)
        rows.append(bytes(row))
    return rows


def _png_bytes(size: int) -> bytes:
    rows = _render_icon(size)
    raw = b"".join(b"\x00" + row for row in rows)
    compressor = zlib.compressobj()
    compressed = compressor.compress(raw) + compressor.flush()

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = bytearray()
    png.extend(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", ihdr))
    png.extend(chunk(b"IDAT", compressed))
    png.extend(chunk(b"IEND", b""))
    return bytes(png)


def _write_png(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_png_bytes(size))


def _write_ico(path: Path, size: int = 256) -> None:
    png = _png_bytes(size)
    path.parent.mkdir(parents=True, exist_ok=True)
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack(
        "<BBBBHHII",
        0 if size >= 256 else size,
        0 if size >= 256 else size,
        0,
        0,
        1,
        32,
        len(png),
        6 + 16,
    )
    with path.open("wb") as fh:
        fh.write(header)
        fh.write(entry)
        fh.write(png)


def main() -> None:
    base = Path(__file__).resolve().parents[1]
    targets: list[tuple[str, int]] = [
        ("assets/logo.png", 512),
        ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
        ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
        ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
        ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
        ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", 16),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", 32),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", 64),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", 128),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", 256),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", 512),
        ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", 1024),
        ("web/favicon.png", 48),
        ("web/icons/Icon-192.png", 192),
        ("web/icons/Icon-512.png", 512),
        ("web/icons/Icon-maskable-192.png", 192),
        ("web/icons/Icon-maskable-512.png", 512),
    ]

    for rel_path, size in targets:
        _write_png(base / rel_path, size)

    _write_ico(base / "windows/runner/resources/app_icon.ico", 256)


if __name__ == "__main__":
    main()
