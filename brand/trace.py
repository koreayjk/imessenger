"""pr-3.png 의 엠블럼을 색깔별로 떼어내 벡터로 딴다."""
import numpy as np, potrace
from PIL import Image

SRC = '/tmp/claude-0/logo/pr-3.png'
im = Image.open(SRC).convert('RGB')
UP = 4
im = im.resize((im.width*UP, im.height*UP), Image.LANCZOS)
a = np.asarray(im).astype(int)
H, W = a.shape[:2]

# 엠블럼만 — 글자 위쪽
TOP, BOT = 230*4, 470*4
sub = a[TOP:BOT, :, :]

r, g, b = sub[:,:,0], sub[:,:,1], sub[:,:,2]
# 남색: 어둡고 파랑이 우세  /  금색: 밝고 빨강·초록이 우세
navy = (b > r + 20) & (r < 120) & (b < 170)
gold = (r > 140) & (g > 110) & (b < 140) & (r > b + 50)

ys, xs = np.nonzero(navy | gold)
print('엠블럼 범위 x', xs.min(), xs.max(), '· y', ys.min()+TOP, ys.max()+TOP)
print('남색 픽셀', int(navy.sum()), '· 금색 픽셀', int(gold.sum()))

x0, x1 = xs.min(), xs.max()+1
y0, y1 = ys.min(), ys.max()+1
navy = navy[y0:y1, x0:x1]
gold = gold[y0:y1, x0:x1]
h, w = navy.shape
print('잘라낸 크기', w, 'x', h)

def trace(mask, turd=140, alpha=1.0, opt=0.2):
    # potracer 는 Bitmap 을 만들 때 스스로 뒤집는다 — 미리 뒤집어 넣는다
    bmp = potrace.Bitmap(~mask.astype(bool))
    path = bmp.trace(turdsize=turd, alphamax=alpha, opttolerance=opt)
    out = []
    for curve in path:
        P = lambda p: (p.x, p.y)
        sx, sy = P(curve.start_point)
        d = [f'M{sx:.2f} {sy:.2f}']
        for seg in curve:
            if seg.is_corner:
                cx, cy = P(seg.c); ex, ey = P(seg.end_point)
                d.append(f'L{cx:.2f} {cy:.2f} L{ex:.2f} {ey:.2f}')
            else:
                c1x, c1y = P(seg.c1); c2x, c2y = P(seg.c2); ex, ey = P(seg.end_point)
                d.append(f'C{c1x:.2f} {c1y:.2f} {c2x:.2f} {c2y:.2f} {ex:.2f} {ey:.2f}')
        d.append('Z')
        out.append(''.join(d))
    return ' '.join(out)

dn = trace(navy)
dg = trace(gold)
print('남색 path 길이', len(dn), '· 금색 path 길이', len(dg))

# 100 박스로 정규화
s = 100.0 / max(w, h)
ox, oy = (100 - w*s)/2, (100 - h*s)/2
open('/tmp/claude-0/brand/traced.py','w').write(
  'W,H = %d,%d\nS = %.6f\nOX,OY = %.3f,%.3f\nNAVY_D = %r\nGOLD_D = %r\n' % (w,h,s,ox,oy,dn,dg))
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
       f'<g transform="translate({ox:.2f} {oy:.2f}) scale({s:.5f})">'
       f'<path d="{dn}" fill="#1d3a5f" fill-rule="evenodd"/>'
       f'<path d="{dg}" fill="#C9A227" fill-rule="evenodd"/></g></svg>')
open('/tmp/claude-0/brand/traced.svg','w').write(svg)
print('svg', len(svg), 'bytes')
