from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Transform

class Face:
    def __init__(self, path):
        self.f = TTFont(path)
        self.upem = self.f['head'].unitsPerEm
        self.gs = self.f.getGlyphSet()
        self.cmap = self.f.getBestCmap()
        try:
            self.kern = self.f['kern'].kernTables[0].kernTable
        except Exception:
            self.kern = {}

    def gname(self, ch):
        return self.cmap.get(ord(ch))

    def text(self, s, size, tracking=0.0):
        """베이스라인 y=0, 시작 x=0, SVG 좌표(아래로 +)로 뒤집은 path d 와 전체 폭."""
        sc = size / self.upem
        x = 0.0
        parts = []
        prev = None
        for ch in s:
            g = self.gname(ch)
            if g is None:
                x += size * 0.3 + tracking
                prev = None
                continue
            if prev is not None:
                x += self.kern.get((prev, g), 0) * sc
            pen = SVGPathPen(self.gs, ntos=lambda v: f'{v:.2f}')
            # y 뒤집기 + 위치 이동
            tp = TransformPen(pen, Transform(sc, 0, 0, -sc, x, 0))
            self.gs[g].draw(tp)
            d = pen.getCommands()
            if d:
                parts.append(d)
            x += self.gs[g].width * sc + tracking
            prev = g
        if s:
            x -= tracking
        return ' '.join(parts), x

    def cap_height(self, size):
        try:
            return self.f['OS/2'].sCapHeight * size / self.upem
        except Exception:
            return size * 0.7
