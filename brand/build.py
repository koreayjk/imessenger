import sys, io, os, math
sys.path.insert(0, '/tmp/claude-0/brand')
from txt import Face
import emblem as EM

NAVY, GOLD, WHITE = '#1d3a5f', '#C9A227', '#ffffff'
BOLD = Face('/tmp/claude-0/brand/mont-800.ttf')
MED  = Face('/tmp/claude-0/brand/mont-500.ttf')
OUT  = '/home/user/imessenger/brand'
os.makedirs(OUT, exist_ok=True)

# ── 엠블럼: 100 박스 안의 실제 내용 범위 ──
EM_X0, EM_X1 = 22.0, 78.0      # 받침 끝 + 선 굵기 포함
EM_Y0, EM_Y1 = 8.0, 67.2
EM_W, EM_H = EM_X1 - EM_X0, EM_Y1 - EM_Y0

def emblem_at(x, y, h, navy=NAVY, gold=GOLD, wick=True):
    """왼쪽 위 (x,y) 에 높이 h 로 엠블럼을 놓는다. (쓴 폭, 높이) 반환."""
    s = h / EM_H
    g = EM.emblem_svg(navy=navy, gold=gold, wick=wick)
    return (f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.4f}) '
            f'translate({-EM_X0} {-EM_Y0})">{g}</g>'), EM_W * s

def fit_tag(target_w, tracking_ratio=0.34, lo=4.0, hi=80.0):
    """태그라인 폭이 target_w 와 같아지는 글자 크기를 찾는다.
       락업은 아랫줄 폭이 윗줄과 맞을 때 가장 정돈돼 보인다."""
    for _ in range(60):
        mid = (lo + hi) / 2
        _, w = MED.text('TOTAL CARE SYSTEM', mid, mid * tracking_ratio)
        if w < target_w: lo = mid
        else: hi = mid
    size = (lo + hi) / 2
    d, w = MED.text('TOTAL CARE SYSTEM', size, size * tracking_ratio)
    return d, w, size, MED.cap_height(size)

def svg(w, h, body, bg=None):
    b = f'<rect width="{w:.1f}" height="{h:.1f}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.1f} {h:.1f}" '
            f'width="{w:.0f}" height="{h:.0f}">{b}{body}</svg>')

def write(name, s):
    io.open(os.path.join(OUT, name), 'w', encoding='utf-8').write(s)
    return name

# ══════════ 세로 락업 ══════════
def vertical(ink=NAVY, gold=GOLD, pad=16):
    S  = 132                       # TCS 글자 크기
    TR = 6                         # 자간
    tcs_d, tcs_w = BOLD.text('TCS', S, TR)
    cap = BOLD.cap_height(S)
    tag_d, tag_w, TG, tag_cap = fit_tag(tcs_w)

    e_h = 104
    e_svg, e_w = emblem_at(0, 0, e_h, navy=ink, gold=gold)

    gap1, gap2, gap3 = 30, 22, 17   # 엠블럼→TCS, TCS→선, 선→태그라인
    rule_w, rule_t = tcs_w * 0.44, 2.6

    W = max(e_w, tcs_w, tag_w) + pad*2
    H = pad + e_h + gap1 + cap + gap2 + rule_t + gap3 + tag_cap + pad
    cx = W/2

    y = pad
    parts = [f'<g transform="translate({cx - e_w/2:.2f} {y:.2f})">{e_svg.split(">",1)[1][:-4]}</g>'] if False else []
    es, _ = emblem_at(cx - e_w/2, y, e_h, navy=ink, gold=gold)
    parts = [es]
    y += e_h + gap1 + cap
    parts.append(f'<path d="{tcs_d}" fill="{ink}" transform="translate({cx - tcs_w/2:.2f} {y:.2f})"/>')
    y += gap2
    parts.append(f'<rect x="{cx - rule_w/2:.2f}" y="{y:.2f}" width="{rule_w:.2f}" height="{rule_t}" fill="{gold}" rx="{rule_t/2}"/>')
    y += rule_t + gap3 + tag_cap
    parts.append(f'<path d="{tag_d}" fill="{ink}" transform="translate({cx - tag_w/2:.2f} {y:.2f})"/>')
    return svg(W, H, ''.join(parts))

# ══════════ 가로 락업 ══════════
def horizontal(ink=NAVY, gold=GOLD, pad=16):
    S, TR = 112, 5
    tcs_d, tcs_w = BOLD.text('TCS', S, TR)
    cap = BOLD.cap_height(S)
    tag_d, tag_w, TG, tag_cap = fit_tag(tcs_w)

    e_h = 108
    _, e_w = emblem_at(0, 0, e_h)
    gapx, gapy = 26, 15
    block_w = max(tcs_w, tag_w)
    W = pad + e_w + gapx + block_w + pad
    H = pad + max(e_h, cap + gapy + tag_cap) + pad

    es, _ = emblem_at(pad, pad + (H - 2*pad - e_h)/2, e_h, navy=ink, gold=gold)
    tx = pad + e_w + gapx
    ty = pad + (H - 2*pad - (cap + gapy + tag_cap))/2
    parts = [es,
             f'<path d="{tcs_d}" fill="{ink}" transform="translate({tx:.2f} {ty + cap:.2f})"/>',
             f'<path d="{tag_d}" fill="{ink}" opacity="0.82" transform="translate({tx:.2f} {ty + cap + gapy + tag_cap:.2f})"/>']
    return svg(W, H, ''.join(parts))

# ══════════ 앱 아이콘 ══════════
def icon(size=512, safe=1.0, bg=NAVY, tile_radius=0.225):
    """safe=1.0 보통 아이콘 / safe=0.78 maskable (바깥이 잘려도 괜찮게)"""
    S, TR = 150, 5
    tcs_d, tcs_w = BOLD.text('TCS', S, TR)
    cap = BOLD.cap_height(S)
    e_h = 118
    _, e_w = emblem_at(0, 0, e_h)
    gap = 30
    content_h = e_h + gap + cap
    content_w = max(e_w, tcs_w)

    box = 512.0
    avail = box * 0.76 * safe
    k = min(avail / content_w, avail / content_h)
    cw, ch = content_w * k, content_h * k
    x0, y0 = (box - cw)/2, (box - ch)/2

    es, few = emblem_at(x0 + (cw - e_w*k)/2, y0, e_h*k, navy=WHITE, gold=GOLD)
    ty = y0 + e_h*k + gap*k + cap*k
    parts = [
      f'<rect width="{box}" height="{box}" rx="{box*tile_radius:.1f}" fill="{bg}"/>',
      es,
      f'<g transform="translate({x0 + (cw - tcs_w*k)/2:.2f} {ty:.2f}) scale({k:.4f})">'
      f'<path d="{tcs_d}" fill="{WHITE}"/></g>',
    ]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box:.0f} {box:.0f}" '
            f'width="{size}" height="{size}">{"".join(parts)}</svg>')

def icon_text_only(size=512, bg=NAVY, tile_radius=0.225):
    S, TR = 150, 4
    tcs_d, tcs_w = BOLD.text('TCS', S, TR)
    cap = BOLD.cap_height(S)
    box = 512.0
    k = (box * 0.72) / tcs_w
    x = (box - tcs_w*k)/2
    y = (box + cap*k)/2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box:.0f} {box:.0f}" width="{size}" height="{size}">'
            f'<rect width="{box}" height="{box}" rx="{box*tile_radius:.1f}" fill="{bg}"/>'
            f'<g transform="translate({x:.2f} {y:.2f}) scale({k:.4f})"><path d="{tcs_d}" fill="{WHITE}"/></g></svg>')

made = []
made.append(write('tcs-logo-vertical.svg',        vertical()))
made.append(write('tcs-logo-vertical-dark.svg',   vertical(ink=WHITE, gold=GOLD)))
made.append(write('tcs-logo-horizontal.svg',      horizontal()))
made.append(write('tcs-logo-horizontal-dark.svg', horizontal(ink=WHITE, gold=GOLD)))
made.append(write('tcs-emblem.svg',
    svg(100, 100, EM.emblem_svg())))
made.append(write('tcs-emblem-dark.svg',
    svg(100, 100, EM.emblem_svg(navy=WHITE))))
made.append(write('tcs-icon.svg',          icon()))
made.append(write('tcs-icon-maskable.svg', icon(safe=0.78, tile_radius=0.0)))
made.append(write('tcs-favicon.svg',       icon_text_only()))
print('\n'.join(made))
