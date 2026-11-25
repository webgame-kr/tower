"""시안 '기존 10종 · 무기형' 보드(1280x720, 2배)에서 기존 포탑 10종 x 4단계를 뽑아
art/towers.png 0~9줄을 바꾼다 (34x50 칸, 단계 4 x 주인 색 4). 주인 색은 발판의 빨간 줄을 바꿔 칠한다.
사용: python tools/extract_weapons.py <보드 png>
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "art", "towers.png")
FW, FH = 34, 50
BOTTOM = 47
# 시안 칸 순서: 왼쪽 열 위→아래, 오른쪽 열 위→아래
ORDER = [("gun", 0, 0), ("cannon", 0, 1), ("cold", 0, 2), ("magnet", 0, 3), ("oil", 0, 4),
         ("flame", 1, 0), ("shock", 1, 1), ("sniper", 1, 2), ("signal", 1, 3), ("spike", 1, 4)]
ROW = {"gun": 0, "cannon": 1, "cold": 2, "magnet": 3, "oil": 4, "flame": 5, "shock": 6, "sniper": 7, "signal": 8, "spike": 9}
OWNER = [(217, 80, 60), (61, 111, 209), (233, 185, 53), (56, 166, 114)]
BG = {(23, 22, 20), (28, 27, 24), (33, 31, 28), (14, 13, 12)}
LABEL_ROWS = 9
LABEL = {(242, 179, 61), (163, 155, 138), (22, 20, 18)}

src = Image.open(sys.argv[1]).convert("RGBA")


def cell(panel, row, col):
    x0 = 146 + (col - 1) * 124 + panel * 636
    y0 = 90 + row * 132
    w, h = 57, 42
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            out.putpixel((x, y), src.getpixel((x0 + 2 * x, y0 + 2 * y)))
    px = out.load()
    # 바깥에서 배경색을 지운다 (외곽선 색은 칸 테두리와 같으니 바깥과 이어진 것만)
    st = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while st:
        x, y = st.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][3] == 0 or px[x, y][:3] in BG:
            px[x, y] = (0, 0, 0, 0)
            st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    # 위쪽 이름표 글자를 지운다: 글자색, 그리고 이름표 줄에서 몸통과 이어지지 않은 덩어리
    for y in range(LABEL_ROWS):
        for x in range(w):
            if px[x, y][:3] in LABEL:
                px[x, y] = (0, 0, 0, 0)
    body = set()
    st = [(x, y) for y in range(LABEL_ROWS, h) for x in range(w) if px[x, y][3]]
    while st:
        x, y = st.pop()
        if (x, y) in body or not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0:
            continue
        body.add((x, y))
        st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for y in range(LABEL_ROWS):
        for x in range(w):
            if (x, y) not in body:
                px[x, y] = (0, 0, 0, 0)
    return out


def recolor(im, k):
    if k == 0:
        return im
    im = im.copy()
    px = im.load()
    r0 = OWNER[0]
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] and abs(c[0] - r0[0]) + abs(c[1] - r0[1]) + abs(c[2] - r0[2]) < 40:
                px[x, y] = OWNER[k] + (255,)
    return im


sheet = Image.open(PATH).convert("RGBA")
for name, panel, row in ORDER:
    for mk in range(4):
        spr = cell(panel, row, mk + 1)
        bb = spr.getbbox()
        spr = spr.crop(bb)
        assert spr.width <= FW and spr.height <= BOTTOM + 1, (name, mk, spr.size)
        for k in range(4):
            fx = ((mk * 4) + k) * FW
            fy = ROW[name] * FH
            sheet.paste((0, 0, 0, 0), (fx, fy, fx + FW, fy + FH))
            sheet.alpha_composite(recolor(spr, k), (fx + (FW - spr.width) // 2, fy + BOTTOM + 1 - spr.height))
sheet.save(PATH)
prev = sheet.crop((0, 0, sheet.width, 10 * FH))
prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).save(os.path.join(ROOT, "art", "_weapons_preview.png"))
print("ok")
