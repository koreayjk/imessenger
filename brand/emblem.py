import math
NAVY = '#1d3a5f'
GOLD = '#C9A227'

# 불꽃 — 끝이 오른쪽으로 기울고 왼쪽 선이 안으로 패인다.
# 물방울과 구분되는 건 이 '기울기' 다.
FLAME = ('M57.5 8'
         ' C49 18.5 35 27 35 41'
         ' A15 15 0 1 0 65 41'
         ' C65 30.5 62 16.5 57.5 8 Z')

# 안쪽 심지 (큰 자리에서만)
WICK = ('M55 27'
        ' C50 33.5 44.5 37.5 44.5 44'
        ' A7.5 7.5 0 1 0 59.5 44'
        ' C59.5 38.5 57.5 32 55 27 Z')

def cradle(cx=50.0, cy=36.0, r=27.0, t0=152.0, t1=28.0, w=7.6):
    """아래로 지나가는 호 — t 가 줄어드는 방향(sweep=0)이 화면에서 아래쪽."""
    p = lambda t: (cx + r*math.cos(math.radians(t)), cy + r*math.sin(math.radians(t)))
    x0, y0 = p(t0); x1, y1 = p(t1)
    return f'M{x0:.2f} {y0:.2f} A{r} {r} 0 0 0 {x1:.2f} {y1:.2f}', w

def emblem_svg(navy=NAVY, gold=GOLD, wick=True):
    d, w = cradle()
    out = [f'<path d="{d}" fill="none" stroke="{navy}" stroke-width="{w}" stroke-linecap="round"/>',
           f'<path d="{FLAME}" fill="{gold}"/>']
    if wick:
        out.append(f'<path d="{WICK}" fill="{navy}"/>')
    return ''.join(out)
