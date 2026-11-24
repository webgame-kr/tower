"""픽셀 아트 시안(길 좀 막아봐 픽셀 아트)의 시트에서 게임 그림을 만든다.
시트는 배경이 깔린 확대 이미지라, 원래 픽셀 크기로 줄이고 테두리에서 이어진 배경을 지운다.
지도는 합성 화면뿐이라 팔레트·장식·본부·랜드마크 스프라이트로 직접 그린다 (타일 19px).

사용: python tools/make_pixel.py <시트 폴더> <art 폴더>
"""
import glob
import json
import os
import random
import sys
from collections import Counter

from PIL import Image

SRC, ART = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(ART, "map"), exist_ok=True)


def load(prefix):
    return Image.open(glob.glob(os.path.join(SRC, prefix + "*.png"))[0]).convert("RGBA")


def shrink(im, k):
    return im.resize((im.width // k, im.height // k), Image.NEAREST)


def unbg(im, keys=None):
    """테두리에서 이어진 배경색(keys, 없으면 테두리 색 전부)을 투명하게"""
    im = im.copy()
    px = im.load()
    w, h = im.size
    if keys is None:
        keys = set()
        for x in range(w):
            keys.add(px[x, 0][:3])
            keys.add(px[x, h - 1][:3])
        for y in range(h):
            keys.add(px[0, y][:3])
            keys.add(px[w - 1, y][:3])
    seen = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        c = px[x, y]
        if c[3] == 0 or c[:3] in keys:
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def shadowize(im, shadow_colors):
    """그림자 색은 반투명 검정으로"""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] and px[x, y][:3] in shadow_colors:
                px[x, y] = (0, 0, 0, 80)
    return im


OWNER = [(217, 80, 60), (61, 111, 209), (233, 185, 53), (56, 166, 114)]

# ── 포탑: 시트 한 장 = MK-1, MK-2, MK-3A, MK-3B (3배), 한 칸 34x50 ──
ORDER = ["gun", "cannon", "cold", "magnet", "oil", "flame", "shock", "sniper", "signal", "spike"]
SHEETS = {"gun": "7a64e101fb", "cannon": "cf181d760c", "cold": "d5c8c52ee2", "magnet": "925cd62d52", "oil": "c4193b6cf0",
          "flame": "9f025f85dc", "shock": "e05bff80ee", "sniper": "0cdd876c3c", "signal": "fb703bb944", "spike": "05a53bf1a6"}
FW, FH = 34, 50
towers = Image.new("RGBA", (FW * 16, FH * 10))
for row, t in enumerate(ORDER):
    sheet = load(SHEETS[t])
    for mk in range(4):
        x0 = mk * 105
        frame = shrink(sheet.crop((x0, 0, x0 + 102, 150)), 3)
        frame = unbg(frame, {(42, 39, 35), (78, 90, 54), (134, 130, 122), (146, 142, 133), (0, 0, 0)})
        for c in range(4):
            f = frame.copy()
            if c:
                px = f.load()
                for y in range(f.height):
                    for x in range(f.width):
                        if px[x, y][:3] == OWNER[0]:
                            px[x, y] = OWNER[c] + (255,)
            towers.paste(f, ((mk * 4 + c) * FW, row * FH))
towers.save(os.path.join(ART, "towers.png"))

# ── 적: 4배, 일반병·돌격병·중장갑·떼거리·치유사·보스 → 한 칸 44x40 ──
EN = ["16d513bafe", "616926ea80", "b5a6a95b01", "c7417b9fa4", "92121db9ac", "39b2d30ed0"]
enemies = Image.new("RGBA", (44 * 6, 40))
foot = []
for i, p in enumerate(EN):
    e = shrink(load(p), 4)
    border = Counter()
    for x in range(e.width):
        border[e.getpixel((x, 0))[:3]] += 1
        border[e.getpixel((x, e.height - 1))[:3]] += 1
    e = unbg(e)
    # 길 바탕 위의 그림자: 바탕보다 어두운 회색 중 가장 많은 색
    cnt = Counter(c[:3] for c in e.getdata() if c[3])
    bg = border.most_common(1)[0][0]
    shadow = [c for c, n in cnt.most_common(8) if sum(c) < sum(bg) and abs(c[0] - c[1]) < 12 and abs(c[1] - c[2]) < 12 and sum(c) > 150]
    e = shadowize(e, set(shadow[:1]))
    bb = e.getbbox()
    foot.append([(bb[0] + bb[2]) // 2, bb[3]])
    enemies.paste(e, (i * 44, 0))
enemies.save(os.path.join(ART, "enemies.png"))

# ── 본부·입구 (3배), 랜드마크 (2배, 120x112 다섯 칸), 장식 (3배, 테마 4열 x 6줄) ──
kit = shrink(load("06eed81974"), 3)
kit_bg = kit.getpixel((1, 1))[:3]
castle = unbg(kit.crop((0, 0, 68, 80)), {kit_bg})
castle = castle.crop(castle.getbbox())
gates = []
for i in range(5):
    cx = 81 + i * 15
    g = unbg(kit.crop((cx - 7, 15, cx + 8, 52)), {kit_bg})
    gates.append(g.crop(g.getbbox()) if g.getbbox() else g)
lm = shrink(load("bf27827a8d"), 2)
landmarks = []
for i in range(5):
    cell = lm.crop((i * 60, 0, i * 60 + 58, 56))
    cell = unbg(cell)
    landmarks.append(cell.crop(cell.getbbox()))
deco = shrink(load("f0a1c914e8"), 3)
DECO = ["tree", "rock", "crate", "barrel", "lamp", "container"]
decor = {}
for col in range(4):
    for row, name in enumerate(DECO):
        cell = deco.crop((col * 40, row * 30, col * 40 + 38, row * 30 + 28))
        cell = unbg(cell)
        bb = cell.getbbox()
        decor[(col, name)] = cell.crop(bb) if bb else cell

prev = Image.new("RGBA", (420, 260), (40, 44, 48, 255))
prev.paste(castle, (0, 0), castle)
for i, g in enumerate(gates):
    prev.paste(g, (120 + i * 18, 0), g)
for i, l in enumerate(landmarks):
    prev.paste(l, (i * 62, 90), l)
for (col, name), d in decor.items():
    prev.paste(d, (col * 42, 150 + DECO.index(name) * 18), d)
prev.save(os.path.join(ART, "_kit_preview.png"))
print("sprites", towers.size, enemies.size, castle.size, [g.size for g in gates], [l.size for l in landmarks], "foot", foot)

# ── 지도: 팔레트·장식으로 직접 그린다 (타일 19px) ──
T = 19
PAL = {   # 땅 3, 길 2, 도색, 연석, 나무 3 (시안 PX-00)
    "grass": [(78, 90, 54), (86, 99, 59), (72, 83, 48), (134, 130, 122), (146, 142, 133), (176, 138, 52), (74, 71, 64), (34, 48, 26), (47, 66, 36), (63, 86, 48)],
    "snow": [(198, 207, 211), (210, 218, 221), (184, 194, 199), (138, 148, 154), (151, 160, 165), (176, 138, 52), (85, 96, 106), (30, 44, 51), (42, 61, 70), (58, 82, 96)],
    "sand": [(176, 149, 106), (188, 161, 118), (160, 134, 96), (110, 104, 95), (122, 116, 106), (196, 156, 54), (62, 58, 52), (52, 68, 42), (70, 88, 58), (90, 112, 72)],
    "lava": [(46, 41, 38), (54, 48, 44), (38, 34, 32), (78, 72, 68), (90, 83, 78), (196, 106, 42), (26, 23, 22), (26, 23, 22), (38, 33, 30), (51, 44, 40)],
    "ghost": [(39, 53, 47), (46, 62, 55), (33, 45, 40), (90, 96, 88), (102, 109, 100), (111, 168, 148), (30, 34, 31), (15, 26, 22), (23, 42, 35), (33, 57, 47)],
}
POND = {"grass": (64, 104, 118), "snow": (168, 196, 210), "sand": (150, 124, 88), "lava": (196, 96, 40), "ghost": (34, 60, 62)}
THEME_COL = {"grass": 0, "snow": 1, "sand": 2, "lava": 3, "ghost": 0}
LAYOUTS = {
    "v2": {"k": 2.0, "o": (110, 56), "W": 21, "H": 13, "castle": (18, 5), "landmark": (6, 5),
           "lanes": [(0, 1), (0, 11)], "extra": (19, 0), "blocked": None, "ponds": [],
           "decor": [((2, 3), "barrel"), ((2, 7), "crate"), ((12, 3), "crate"), ((13, 8), "lamp"), ((6, 12), "container"),
                     ((1, 6), "rock"), ((11, 10), "rock"), ((19, 10), "rock"), ((8, 0), "rock")]},
    "v4": {"k": 30 / 19, "o": (168, 73), "W": 25, "H": 15, "castle": (11, 6), "landmark": (11, 0),
           "lanes": [(0, 1), (24, 1), (0, 13), (24, 13)], "extra": (12, 14), "blocked": (11, 11, 3, 4),
           "ponds": [(1, 6, 3, 3), (21, 6, 3, 3)],
           "decor": [((5, 7), "rock"), ((19, 7), "rock"), ((8, 0), "rock"), ((9, 0), "rock"), ((15, 0), "rock"), ((16, 0), "rock"),
                     ((8, 14), "rock"), ((9, 14), "rock"), ((15, 14), "rock"), ((16, 14), "rock")]},
}
THEMES = ["grass", "snow", "sand", "lava", "ghost"]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def ghostly(im):
    """장식 시트에 없는 유령 숲: 초원 장식을 어둡고 푸르게"""
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.55), int(g * 0.75), int(b * 0.7), a)
    return im


def put(img, spr, bx, by):
    """스프라이트의 발(아래 가운데)을 (bx, by)에"""
    img.alpha_composite(spr, (int(bx - spr.width // 2), int(by - spr.height)))


for lname, L in LAYOUTS.items():
    k = L["k"]
    size = (int(-(-1280 // k)), int(-(-720 // k)))
    ox, oy = L["o"]
    gw, gh = L["W"] * T, L["H"] * T
    for ti, theme in enumerate(THEMES):
        P = PAL[theme]
        rnd = random.Random(7 + ti)
        base = Image.new("RGBA", size, shade(P[2], 0.82) + (255,))
        bp = base.load()
        for _ in range(size[0] * size[1] // 18):      # 바깥 땅 잔무늬
            x, y = rnd.randrange(size[0]), rnd.randrange(size[1])
            bp[x, y] = shade(P[rnd.randrange(3)], 0.78) + (255,)
        inner = (ox - 6, oy - 6, ox + gw + 6, oy + gh + 6)
        for y in range(inner[1], inner[3]):
            for x in range(inner[0], inner[2]):
                bp[x, y] = P[0] + (255,)
        for _ in range(40):      # 큰 얼룩
            cx, cy = rnd.randrange(inner[0], inner[2]), rnd.randrange(inner[1], inner[3])
            rx, ry = rnd.randrange(10, 34), rnd.randrange(6, 20)
            c2 = P[1] if rnd.random() < 0.6 else P[2]
            for y in range(cy - ry, cy + ry):
                for x in range(cx - rx, cx + rx):
                    if inner[0] <= x < inner[2] and inner[1] <= y < inner[3] and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1 - rnd.random() * 0.15:
                        bp[x, y] = c2 + (255,)
        for _ in range(gw * gh // 40):      # 풀 점
            x, y = rnd.randrange(inner[0], inner[2]), rnd.randrange(inner[1], inner[3])
            bp[x, y] = shade(P[rnd.randrange(3)], 0.85 if rnd.random() < 0.5 else 1.12) + (255,)
        for (px_, py_, pw, ph) in L["ponds"]:      # 연못: 테마마다 물·얼음·마른 땅·용암
            cx, cy = ox + (px_ + pw / 2) * T, oy + (py_ + ph / 2) * T
            rx, ry = pw * T / 2 - 1, ph * T / 2 - 2
            for y in range(int(cy - ry), int(cy + ry)):
                for x in range(int(cx - rx), int(cx + rx)):
                    d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                    if d < 1:
                        c3 = shade(POND[theme], 0.7) if d > 0.82 else (shade(POND[theme], 1.15) if d < 0.25 and (x + y) % 5 == 0 else POND[theme])
                        bp[x, y] = c3 + (255,)
        over = Image.new("RGBA", size, (0, 0, 0, 0))
        stand = []
        col = THEME_COL[theme]

        def deco(name):
            spr = decor[(col, name)]
            return ghostly(spr) if theme == "ghost" else spr

        def outside(x, y):
            return not (inner[0] - 10 < x < inner[2] + 10 and inner[1] - 2 < y < inner[3] + 16)

        for _ in range(size[0] * size[1] // 520):      # 바깥 숲
            x, y = rnd.randrange(-8, size[0] + 8), rnd.randrange(0, size[1] + 20)
            if outside(x, y):
                stand.append((y, deco("tree"), x))
        for _ in range(size[0] * size[1] // 9000):
            x, y = rnd.randrange(0, size[0]), rnd.randrange(0, size[1])
            if outside(x, y):
                stand.append((y, deco("rock"), x))
        for (cx, cy), name in L["decor"]:
            bx = ox + cx * T + (T if name == "container" else T // 2)
            stand.append((oy + (cy + 1) * T - 2, deco(name), bx))
        if L["blocked"] and theme != "ghost":      # 막힌 숲 (유령 숲에서 열린다)
            bx0, by0, bw, bh = L["blocked"]
            for yy in range(bh):
                for xx in range(bw):
                    stand.append((oy + (by0 + yy + 1) * T - 1, deco("tree"), ox + (bx0 + xx) * T + T // 2))
        cx, cy = L["castle"]
        stand.append((oy + (cy + 3) * T, castle, ox + (cx + 1.5) * T))
        lx, ly = L["landmark"]
        stand.append((oy + (ly + 3) * T - 1, landmarks[ti], ox + (lx + 1.5) * T))
        gates_here = list(L["lanes"]) + ([L["extra"]] if theme == "ghost" else [])
        for i, (gx, gy) in enumerate(gates_here):
            g = gates[min(i, 4)]
            if gx == 0:
                bx, by = ox + 3, oy + gy * T + 1
            elif gx == L["W"] - 1:
                bx, by = ox + gw - 3, oy + gy * T + 1
            elif gy == 0:
                bx, by = ox + gx * T - 3, oy + T
            else:
                bx, by = ox + gx * T - 3, oy + gh
            stand.append((by, g, bx))
        stand.sort(key=lambda r: r[0])
        for y, spr, x in stand:
            put(over, spr, x, y)
        base.save(os.path.join(ART, "map", f"{lname}_{theme}_base.png"))
        over.save(os.path.join(ART, "map", f"{lname}_{theme}_over.png"))
        print(lname, theme, size)
