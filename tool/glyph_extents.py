"""glyph_extents.py <Roboto-Regular.ttf> : prints the ink extents of Roboto's glyphs at the default instance, one
line per code point: `0xXXXX, xMin, yMin, xMax, yMax, advance,` in font units (2048 per em), y up. Glyphs without
ink (space) have all four extents 0. The font is Android's /system/fonts/Roboto-Regular.ttf
(`adb pull /system/fonts/Roboto-Regular.ttf`); needs fontTools. Run Python with -I."""
import sys
from fontTools.ttLib import TTFont

f = TTFont(sys.argv[1])
cmap, glyf, hmtx = f.getBestCmap(), f["glyf"], f["hmtx"]
points = list(range(0x20, 0x7F)) + list(range(0xA0, 0x100)) + [
    0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x2030, 0x2032, 0x2033, 0x20AC, 0x2122, 0x2190,
    0x2191, 0x2192, 0x2193, 0x2212, 0x2248, 0x2260, 0x2264, 0x2265,
]
print("// unitsPerEm", f["head"].unitsPerEm, "ascent", f["hhea"].ascent, "descent", f["hhea"].descent,
      "top (head.yMax)", f["head"].yMax, "bottom (head.yMin)", f["head"].yMin)
for cp in points:
    name = cmap.get(cp)
    if name is None:
        continue
    g, (adv, _) = glyf[name], hmtx[name]
    if getattr(g, "numberOfContours", 0) == 0 or not hasattr(g, "xMin"):
        print(f"0x{cp:04X}, 0, 0, 0, 0, {adv},")
    else:
        print(f"0x{cp:04X}, {g.xMin}, {g.yMin}, {g.xMax}, {g.yMax}, {adv},")
