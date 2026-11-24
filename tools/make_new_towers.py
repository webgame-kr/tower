"""새 포탑 8종을 기존 도트 규칙대로 그려 art/towers.png 아래에 붙인다 (34x50 칸, 4단계 x 4색).
기존 10줄은 그대로 두고 11~18줄을 새로 그린다. 여러 번 돌려도 같다.
사용: python tools/make_new_towers.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "art", "towers.png")
FW, FH = 34, 50
NEW = ["steam", "crane", "generator", "conveyor", "welder", "cryo", "searchlight", "scrap"]
OWNER = [(217, 80, 60), (61, 111, 209), (233, 185, 53), (56, 166, 114)]
O = (14, 13, 12)
M1, M2, M3, M4 = (196, 200, 206), (150, 155, 162), (112, 117, 126), (78, 82, 90)      # 금속 밝음→어둠 (빛은 왼쪽 위)
Y1, Y2 = (233, 185, 53), (170, 128, 30)


class Pen:
    def __init__(self, im, ox):
        self.im = im
        self.ox = ox

    def px(self, x, y, c):
        if 0 <= x < FW and 0 <= y < FH:
            self.im.putpixel((self.ox + x, y), c + (255,))

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c)

    def box(self, x, y, w, h, fill, light=None, dark=None):
        """테두리 1px + 왼쪽 위 밝은 선, 오른쪽 아래 어두운 선"""
        self.rect(x, y, w, h, O)
        self.rect(x + 1, y + 1, w - 2, h - 2, fill)
        if light:
            self.rect(x + 1, y + 1, w - 2, 1, light)
            self.rect(x + 1, y + 1, 1, h - 2, light)
        if dark:
            self.rect(x + 1, y + h - 2, w - 2, 1, dark)
            self.rect(x + w - 2, y + 1, 1, h - 2, dark)

    def disc(self, cx, cy, r, fill, edge=O):
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                d = xx * xx + yy * yy
                if d <= r * r:
                    self.px(cx + xx, cy + yy, edge if d > (r - 1) * (r - 1) else fill)


def plinth(p, col):
    p.box(2, 40, 30, 9, M3, M2, M4)
    p.rect(3, 41, 28, 2, M2)
    p.rect(5, 45, 7, 2, col)
    p.rect(26, 43, 4, 3, Y1)
    p.px(27, 44, O)
    p.px(29, 43, O)
    for x in (6, 15, 24):
        p.px(x, 47, M1)


def lamp(p, x, y, col):
    p.rect(x - 1, y - 1, 4, 4, O)
    p.rect(x, y, 2, 2, col)
    p.px(x, y, tuple(min(255, v + 60) for v in col))


def steam(p, mk, col):
    h = 22 if mk == 0 else 26
    top = 40 - h
    p.box(8, top, 16, h + 1, M2, M1, M4)
    p.rect(9, top + 6, 14, 3, (196, 90, 60) if mk != 3 else (120, 170, 200))
    p.box(23, top + 8, 6, 4, M3, M2, M4)
    p.box(26, top + 2, 4, 10, M3, M2, M4)
    if mk >= 1:
        p.disc(13, top + 14, 3, Y2)
        p.px(13, top + 14, O)
    if mk == 2:      # 압력솥: 큰 돔과 압력계
        p.box(7, top - 4, 18, 6, (180, 70, 50), (220, 110, 80), (120, 40, 30))
        p.disc(19, top + 16, 3, M1)
        p.px(19, top + 15, (200, 40, 40))
    if mk == 3:      # 안개: 옅은 안개 덩이
        for i, (x, y) in enumerate([(10, top - 3), (16, top - 6), (22, top - 3), (27, top - 2)]):
            p.disc(x, y, 3, (214, 232, 238), (150, 180, 190))
    else:
        for x, y in [(27, top - 1), (25, top - 4), (28, top - 6)]:
            p.rect(x, y, 3, 2, (232, 236, 238))
    lamp(p, 10, top + 2, col)


def crane(p, mk, col):
    h = 26 if mk == 0 else 31
    top = 40 - h
    p.box(9, top, 6, h + 1, Y1, (250, 214, 110), Y2)
    for y in range(top + 3, 40, 4):
        p.px(11, y, O)
        p.px(12, y + 2, O)
    jl = 18 if mk == 0 else 21
    p.box(6, top, jl, 4, Y1, (250, 214, 110), Y2)
    p.rect(6 + jl - 3, top + 4, 1, 8, O)
    if mk == 3:      # 자석 갈고리
        p.box(6 + jl - 7, top + 12, 9, 5, (160, 60, 160), (200, 110, 200), (110, 30, 110))
        p.rect(6 + jl - 5, top + 14, 5, 3, (14, 13, 12))
    elif mk == 2:    # 들었다 놓기: 매달린 고철 덩이
        p.box(6 + jl - 8, top + 12, 10, 8, M3, M2, M4)
        p.px(6 + jl - 5, top + 15, M1)
    else:
        p.rect(6 + jl - 5, top + 12, 5, 2, O)
        p.rect(6 + jl - 5, top + 14, 1, 2, O)
    p.box(4, top - 2, 5, 6, M3, M2, M4)
    lamp(p, 11, top - 3, col)


def generator(p, mk, col):
    h = 18 if mk == 0 else 21
    top = 40 - h
    p.box(5, top, 24, h + 1, M2, M1, M4)
    p.box(8, top + 4, 10, 10, (40, 44, 50), M3, O)
    for x, y in [(13, top + 5), (12, top + 7), (14, top + 7), (13, top + 9), (12, top + 11)]:
        p.px(x, y, Y1)
        p.px(x + 1, y, Y1)
    for i in range(2 if mk == 0 else 3):
        p.box(20, top + 3 + i * 5, 6, 4, (184, 120, 60), (220, 160, 90), (130, 80, 40))
    if mk == 2:      # 변전소: 애자
        for x in (8, 14, 20):
            p.box(x, top - 7, 4, 7, (220, 226, 230), (250, 250, 250), (160, 170, 176))
            p.px(x + 1, top - 8, O)
    if mk == 3:      # 비상 배터리
        for x in (7, 13, 19):
            p.box(x, top - 6, 5, 7, (80, 170, 90), (130, 210, 140), (40, 110, 50))
            p.rect(x + 1, top - 7, 3, 1, O)
    lamp(p, 26, top - 2, col)


def conveyor(p, mk, col):
    w = 26 if mk == 0 else 30
    x0 = (FW - w) // 2
    p.box(x0, 30, w, 10, M4, M3, O)
    p.rect(x0 + 1, 31, w - 2, 3, (60, 62, 66))
    arrow = (230, 80, 60) if mk == 2 else ((110, 180, 230) if mk == 3 else Y1)
    for i in range(3):
        ax = x0 + 5 + i * (w // 3)
        if mk == 2:
            p.px(ax + 2, 32, arrow); p.px(ax + 1, 31, arrow); p.px(ax + 1, 33, arrow); p.px(ax + 3, 32, arrow)
        else:
            p.px(ax, 32, arrow); p.px(ax + 1, 31, arrow); p.px(ax + 1, 33, arrow); p.px(ax - 1, 32, arrow)
    for i in range(w // 5):
        p.disc(x0 + 3 + i * 5, 37, 1, M1)
    lamp(p, x0 + w - 4, 27, col)


def welder(p, mk, col):
    p.box(9, 26, 14, 15, M2, M1, M4)
    p.box(11, 16, 5, 11, M3, M2, M4)
    p.box(14, 13, 12, 5, M3, M2, M4)
    tip = (120, 180, 255) if mk < 2 else ((180, 90, 230) if mk == 2 else M1)
    if mk == 3:      # 절단기: 원형 톱날
        p.disc(26, 18, 5, M1, O)
        for k in range(8):
            import math
            a = k * math.pi / 4
            p.px(26 + round(math.cos(a) * 5), 18 + round(math.sin(a) * 5), M4)
        p.px(26, 18, O)
    else:
        p.box(25, 14, 4, 4, M4, M3, O)
        p.rect(29, 15, 2, 2, tip)
        p.px(31, 15, (255, 230, 120))
        p.px(30, 13, (255, 200, 80))
        p.px(31, 18, (255, 160, 60))
    if mk >= 1:
        p.box(19, 30, 8, 8, (60, 66, 74), M3, O)
        p.px(22, 33, (120, 180, 255))
    lamp(p, 12, 23, col)


def cryo(p, mk, col):
    p.box(6, 24, 22, 17, M2, M1, M4)
    p.rect(7, 30, 20, 2, (110, 190, 230))
    if mk == 3:      # 확산탄: 작은 미사일 여럿
        for i in range(3):
            x = 9 + i * 6
            p.box(x, 13, 4, 12, (230, 236, 240), (255, 255, 255), (170, 186, 196))
            p.rect(x + 1, 12, 2, 2, (110, 190, 230))
    else:
        big = mk == 2
        mw = 6 if big else 5
        mh = 17 if big else (14 if mk == 0 else 16)
        for i in range(1 if big else 2):
            x = 11 + i * 8 if not big else 14
            p.box(x, 25 - mh, mw, mh, (230, 236, 240), (255, 255, 255), (170, 186, 196))
            p.rect(x + 1, 25 - mh - 1, mw - 2, 2, (110, 190, 230))
            p.rect(x - 1, 22, 2, 3, (110, 190, 230))
    lamp(p, 24, 26, col)


def searchlight(p, mk, col):
    p.box(14, 22 if mk == 0 else 18, 5, 20 if mk == 0 else 24, M3, M2, M4)
    top = 12 if mk == 0 else 8
    r = 6 if mk == 0 else 7
    p.disc(16, top + r, r, M2)
    lens = (255, 236, 150) if mk != 3 else (255, 255, 255)
    p.disc(17, top + r, r - 2, lens, (200, 170, 70))
    p.px(15, top + r - 2, (255, 255, 255))
    if mk == 2:      # 서치라이트: 길게 뻗는 빛
        for i in range(6):
            p.rect(24 + i, top + r - 1 - i // 2, 1, 3 + i, (255, 240, 170))
    if mk == 3:      # 섬광: 빛살
        for dx, dy in [(-9, 0), (9, 0), (0, -9), (6, -6), (-6, -6)]:
            p.px(17 + dx, top + r + dy, (255, 255, 255))
            p.px(17 + dx + (1 if dx > 0 else -1 if dx < 0 else 0), top + r + dy + (1 if dy > 0 else -1 if dy < 0 else 0), (255, 255, 200))
    lamp(p, 21, 36, col)


def scrap(p, mk, col):
    p.box(5, 30, 24, 11, M3, M2, M4)
    p.box(9, 14, 4, 18, (130, 90, 50), (170, 120, 70), (90, 60, 30))      # 투척 팔
    p.box(6, 10, 12, 6, M4, M3, O)
    if mk == 3:      # 강철구
        p.disc(12, 8, 4, M1)
        p.px(11, 7, (255, 255, 255))
    else:
        rust = [(150, 80, 40), (120, 70, 50), (170, 110, 60)]
        n = 3 if mk == 0 else 5
        for i in range(n):
            p.rect(7 + (i * 3) % 10, 7 - (i % 2) * 2, 3, 3, rust[i % 3])
    if mk == 2 or mk == 1:      # 고철 더미
        for i in range(4 if mk == 2 else 2):
            p.rect(18 + i * 3, 26 - (i % 2) * 2, 3, 4, [(150, 80, 40), (110, 110, 116), (170, 110, 60), (90, 94, 100)][i])
    lamp(p, 25, 31, col)


DRAW = {"steam": steam, "crane": crane, "generator": generator, "conveyor": conveyor, "welder": welder,
        "cryo": cryo, "searchlight": searchlight, "scrap": scrap}

old = Image.open(PATH).convert("RGBA")
rows = 10 + len(NEW)
atlas = Image.new("RGBA", (FW * 16, FH * rows))
atlas.paste(old.crop((0, 0, FW * 16, FH * 10)), (0, 0))
for r, name in enumerate(NEW):
    for mk in range(4):
        for c in range(4):
            ox = (mk * 4 + c) * FW
            frame = Image.new("RGBA", (FW * 16, FH), (0, 0, 0, 0))
            p = Pen(frame, ox)
            if name != "conveyor":
                plinth(p, OWNER[c])
            else:
                p.box(2, 40, 30, 9, M4, M3, O)
                p.rect(5, 45, 7, 2, OWNER[c])
            DRAW[name](p, mk, OWNER[c])
            atlas.alpha_composite(frame.crop((ox, 0, ox + FW, FH)), (ox, (10 + r) * FH))
atlas.save(PATH)
prev = atlas.crop((0, FH * 10, FW * 16, FH * rows)).resize((FW * 16 * 2, FH * len(NEW) * 2), Image.NEAREST)
prev.save(os.path.join(ROOT, "art", "_new_towers_preview.png"))
print("atlas", atlas.size)
