#!/usr/bin/env python3
"""Draw the README art: hero.svg, wheels.svg and the 1280x640 social card.

The wheel uses the same rounded-segment trick as WheelGeometry.slicePath
(shrink each slice by `corner`, then stroke it back with round joins).
Run from the repo root: python3 assets/readme/source/make_assets.py
"""
from math import asin, cos, pi, sin
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent

BG, INK, ORANGE, PEEL, MUTED = "#FFF6EC", "#2B1A12", "#F26A21", "#FFE2C7", "#9A7B63"
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, monospace"


def slice_path(i, n, cx, cy, inner, outer, gap, corner):
    """SVG path for slice i of n; 0 at 12 o'clock, clockwise (y-down)."""
    ri, ro, d = inner + corner, outer - corner, gap / 2 + corner
    step, mid = 2 * pi / n, 2 * pi * i / n

    def pt(r, a):
        return f"{cx + r * sin(a):.1f} {cy - r * cos(a):.1f}"

    def span(r):
        off = asin(min(1, d / r))
        return mid - step / 2 + off, mid + step / 2 - off

    (o0, o1), (i0, i1) = span(ro), span(ri)
    big = 1 if o1 - o0 > pi else 0
    return (f"M{pt(ro, o0)} A{ro:.1f} {ro:.1f} 0 {big} 1 {pt(ro, o1)} "
            f"L{pt(ri, i1)} A{ri:.1f} {ri:.1f} 0 0 0 {pt(ri, i0)} Z")


def wheel(cx, cy, labels, hot=None, outer=172, inner=50, size=24, center=None, gid="wheel"):
    n, corner = len(labels), 14
    parts = [f'<g id="{gid}">',
             f'<circle cx="{cx}" cy="{cy}" r="{outer + 10}" fill="{ORANGE}" opacity="0.08"/>']
    for i, label in enumerate(labels):
        d = slice_path(i, n, cx, cy, inner, outer, 9, corner)
        fill = PEEL
        parts.append(f'<path d="{d}" fill="{fill}" stroke="{fill}" '
                     f'stroke-width="{2 * corner}" stroke-linejoin="round"/>')
    for i, label in enumerate(labels):
        a, r = 2 * pi * i / n, (inner + outer) / 2 + 6
        x, y = cx + r * sin(a), cy - r * cos(a)
        color = INK if i != hot else "#FFFFFF"
        parts.append(f'<text x="{x:.1f}" y="{y + size * 0.36:.1f}" text-anchor="middle" '
                     f'font-family="{SANS}" font-size="{size}" font-weight="700" '
                     f'fill="{color}" data-slice="{i}">{label}</text>')
    if center:
        parts.append(f'<text x="{cx}" y="{cy + 7}" text-anchor="middle" font-family="{SANS}" '
                     f'font-size="19" font-weight="700" fill="{MUTED}">{center}</text>')
    parts.append("</g>")
    return parts


def hot_slice(cx, cy, n, i, outer=172, inner=50, gid="hot"):
    d = slice_path(i, n, cx, cy, inner, outer, 9, 14)
    return [f'<g id="{gid}"><path d="{d}" fill="{ORANGE}" stroke="{ORANGE}" '
            f'stroke-width="28" stroke-linejoin="round"/></g>']


def label_on_top(cx, cy, n, i, label, outer=172, inner=50, gid="hot-label"):
    a, r = 2 * pi * i / n, (inner + outer) / 2 + 6
    x, y = cx + r * sin(a), cy - r * cos(a)
    return [f'<g id="{gid}"><text x="{x:.1f}" y="{y + 8.6:.1f}" text-anchor="middle" '
            f'font-family="{SANS}" font-size="24" font-weight="700" fill="#FFFFFF">{label}</text></g>']


def wheel_center(cx, cy, name, inner=50):
    """Centre label as the app draws it while a slice is hovered."""
    return [f'<g id="hot-center"><circle cx="{cx}" cy="{cy}" r="{inner - 2}" fill="{BG}"/>'
            f'<text x="{cx}" y="{cy + 8}" text-anchor="middle" font-family="{SANS}" '
            f'font-size="22" font-weight="800" fill="{ORANGE}">{name}</text></g>']


def file_card(x, y, ext, ext_color, gid):
    """A dragged file: page with folded corner and an extension tag."""
    return [f'<g id="{gid}" transform="translate({x} {y})">',
            '<path d="M0 0 H44 L62 18 V78 H0 Z" fill="#FFFFFF" stroke="#E7CDB5" stroke-width="2" stroke-linejoin="round"/>',
            '<path d="M44 0 V18 H62" fill="none" stroke="#E7CDB5" stroke-width="2" stroke-linejoin="round"/>',
            f'<rect x="-8" y="44" width="56" height="22" rx="6" fill="{ext_color}"/>',
            f'<text x="20" y="60" text-anchor="middle" font-family="{SANS}" font-size="13" '
            f'font-weight="800" fill="#FFFFFF">{ext}</text>',
            "</g>"]


def cursor(x, y):
    return [f'<g transform="translate({x} {y})"><path d="M0 0 L0 30 L8 23 L14 36 L20 33 L14 21 L25 21 Z" '
            f'fill="{INK}" stroke="#FFFFFF" stroke-width="2.5" stroke-linejoin="round"/></g>']


def svg(w, h, title, desc, body, rx=28):
    return "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'role="img" aria-labelledby="title desc">',
        f'<title id="title">{title}</title>', f'<desc id="desc">{desc}</desc>',
        f'<rect id="bg" width="{w}" height="{h}" rx="{rx}" fill="{BG}"/>', *body, "</svg>\n"])


FORMATS = ["JPG", "PNG", "AVIF", "WebP", "TIFF"]  # what a HEIC photo gets, in ImageConverter.all order
HOT = 3


def hero():
    cx, cy = 900, 214
    # Pointer sits near the rim of the WebP slice; the file trails it in from the left.
    a = 2 * pi * HOT / len(FORMATS) + 0.33
    px, py = cx + 166 * sin(a), cy - 166 * cos(a)
    body = [
        f'<g id="title-block" font-family="{SANS}">',
        f'<text x="64" y="92" font-family="{MONO}" font-size="18" letter-spacing="2" fill="{ORANGE}">MAC MENU-BAR FILE CONVERTER</text>',
        f'<text x="60" y="190" font-size="104" font-weight="800" letter-spacing="-3" fill="{INK}">Tangelo</text>',
        f'<text x="64" y="248" font-size="32" font-weight="600" fill="{INK}">Drag a file. Hold <tspan fill="{ORANGE}">⌃</tspan>.</text>',
        f'<text x="64" y="290" font-size="32" font-weight="600" fill="{INK}">Drop it on a slice.</text>',
        f'<text x="64" y="352" font-family="{MONO}" font-size="19" fill="{MUTED}">photo.heic  →  photo.webp, right next to it</text>',
        "</g>",
        *wheel(cx, cy, FORMATS, center="Convert"),
        *hot_slice(cx, cy, len(FORMATS), HOT),
        *label_on_top(cx, cy, len(FORMATS), HOT, FORMATS[HOT]),
        *wheel_center(cx, cy, FORMATS[HOT]),
        '<g id="drag">', *file_card(px - 112, py - 44, "HEIC", "#8E8E93", "drag-file"), *cursor(px, py), "</g>",
    ]
    return svg(1200, 420, "Tangelo: drag a file, hold Control, drop it on a slice",
               "A glass wheel of format slices (JPG, PNG, AVIF, WebP, TIFF) opens at the pointer while a "
               "photo.heic file is dragged; the WebP slice is lit orange.", body)


def wheels():
    sets = [("⌃  Control", "Convert", FORMATS),
            ("⌘  Command", "Tools", ["Compress", "Resize 50%", "Smaller PDF"]),
            ("⌥  Option", "Actions", ["AirDrop", "Copy", "Paths", "Terminal", "Finder"])]
    body = []
    for k, (key, name, labels) in enumerate(sets):
        cx = 210 + k * 390
        body += wheel(cx, 210, labels, outer=150, inner=44, size=19, center=name, gid=f"wheel-{k}")
        body.append(f'<text x="{cx}" y="418" text-anchor="middle" font-family="{SANS}" font-size="30" '
                    f'font-weight="800" fill="{INK}">{key}</text>')
        body.append(f'<text x="{cx}" y="452" text-anchor="middle" font-family="{SANS}" font-size="20" '
                    f'fill="{MUTED}">hold while dragging</text>')
    return svg(1200, 490, "Three wheels, one per modifier key",
               "Control opens Convert (JPG, PNG, AVIF, WebP, TIFF). Command opens Tools (Compress, "
               "Resize, Smaller PDF). Option opens Actions (AirDrop, Copy Files, Copy Paths, Open in "
               "Terminal, Show in Finder).", body)


def footer():
    """The app icon's cut fruit, small, on a transparent background."""
    paths = [f'<path d="{slice_path(i, 8, 60, 60, 12, 54, 5, 4)}" fill="{ORANGE}" stroke="{ORANGE}" '
             f'stroke-width="8" stroke-linejoin="round"/>' for i in range(8)]
    return "\n".join([
        '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120" role="img" '
        'aria-labelledby="title"><title id="title">Tangelo</title>', *paths, "</svg>\n"])


def social():
    cx, cy = 930, 320
    body = [
        f'<g font-family="{SANS}">',
        f'<text x="88" y="250" font-family="{MONO}" font-size="24" letter-spacing="3" fill="{ORANGE}">MAC MENU-BAR FILE CONVERTER</text>',
        f'<text x="82" y="370" font-size="136" font-weight="800" letter-spacing="-4" fill="{INK}">Tangelo</text>',
        f'<text x="88" y="440" font-size="38" font-weight="600" fill="{INK}">Drag. Hold <tspan fill="{ORANGE}">⌃</tspan>. Drop on a slice.</text>',
        "</g>",
        f'<g transform="translate({cx} {cy}) scale(1.25) translate({-cx} {-cy})">',
        *wheel(cx, cy, FORMATS, center="Convert"),
        *hot_slice(cx, cy, len(FORMATS), HOT),
        *label_on_top(cx, cy, len(FORMATS), HOT, FORMATS[HOT]),
        *wheel_center(cx, cy, FORMATS[HOT]),
        "</g>",
    ]
    return svg(1280, 640, "Tangelo", "Tangelo, a Mac menu-bar file converter with a wheel of format slices.",
               body, rx=0)


if __name__ == "__main__":
    for name, text in [("hero.svg", hero()), ("wheels.svg", wheels()),
                       ("source/social-card.svg", social()), ("footer.svg", footer())]:
        (OUT / name).write_text(text)
        print("wrote", OUT / name)
