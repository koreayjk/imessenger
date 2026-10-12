"""⑫안의 불꽃 엠블럼 — 고른 원본 그림을 그대로 벡터로 따낸 것.
   손으로 다시 그리지 않고 윤곽을 딴 이유: 고르신 건 '그 모양' 이기 때문이다."""
import sys
sys.path.insert(0, '/tmp/claude-0/brand')
from traced import NAVY_D, GOLD_D, S, OX, OY, W, H

NAVY = '#1d3a5f'
GOLD = '#C9A227'

# 100 박스 안에서 그림이 실제로 차지하는 자리
EM_X0, EM_X1 = OX, OX + W * S
EM_Y0, EM_Y1 = OY, OY + H * S

def emblem_svg(navy=NAVY, gold=GOLD, **_):
    return (f'<g transform="translate({OX:.2f} {OY:.2f}) scale({S:.5f})">'
            f'<path d="{NAVY_D}" fill="{navy}" fill-rule="evenodd"/>'
            f'<path d="{GOLD_D}" fill="{gold}" fill-rule="evenodd"/></g>')
