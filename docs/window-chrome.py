#!/usr/bin/env -S uv run --quiet --with pillow --script
"""Wrap a terminal screenshot in neutral window chrome.

    window-chrome.py <in.png> <out.png> [title]

Rounded corners, a title bar with the usual three buttons, and a soft drop
shadow on a transparent background -- so the result sits on either a light or
a dark README without a visible backing box.

Run directly (the shebang pulls Pillow in via uv) or as `python3 window-chrome.py`
if Pillow is already installed.
"""

import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BAR_H = 38  # title bar height
RADIUS = 12  # window corner radius
MARGIN = 44  # transparent space around the window, for the shadow
BAR_BG = (58, 58, 62, 255)
TITLE_FG = (168, 168, 174, 255)
BUTTONS = [(255, 95, 87), (254, 188, 46), (40, 200, 64)]
SHADOW = (0, 0, 0, 92)
SHADOW_DROP = 16  # how far the shadow falls
SHADOW_BLUR = 22
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def main() -> int:
    if not 3 <= len(sys.argv) <= 4:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    title = sys.argv[3] if len(sys.argv) == 4 else ""

    term = Image.open(src).convert("RGBA")
    w, h = term.size
    win_w, win_h = w, h + BAR_H

    # The window: title bar on top of the terminal, corners rounded off.
    win = Image.new("RGBA", (win_w, win_h), BAR_BG)
    win.paste(term, (0, BAR_H))

    d = ImageDraw.Draw(win)
    cy = BAR_H // 2
    for i, colour in enumerate(BUTTONS):
        cx = 20 + i * 20
        d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=colour + (255,))

    if title:
        try:
            font = ImageFont.truetype(FONT, 13)
        except OSError:
            font = ImageFont.load_default()
        d.text((win_w // 2, cy), title, font=font, fill=TITLE_FG, anchor="mm")

    mask = Image.new("L", (win_w, win_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, win_w - 1, win_h - 1), RADIUS, fill=255)
    win.putalpha(mask)

    # Shadow: the window silhouette, blurred, offset downwards.
    out = Image.new("RGBA", (win_w + 2 * MARGIN, win_h + 2 * MARGIN), (0, 0, 0, 0))
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (MARGIN, MARGIN + SHADOW_DROP, MARGIN + win_w - 1, MARGIN + win_h - 1 + SHADOW_DROP),
        RADIUS,
        fill=SHADOW,
    )
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)))
    out.alpha_composite(win, (MARGIN, MARGIN))

    out.save(dst)
    print(f"{dst} ({out.width}x{out.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
