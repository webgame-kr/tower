"""큰 맵(2인 40x24, 3~4인 52x30)의 배치와 지도 그림을 만든다.
배치는 여기 한 곳에서 정하고 scripts/sim/maps.gd 로 내보낸다 (규칙 코드는 그 값만 읽는다).
사용: python tools/make_maps.py <시트 폴더> <art 폴더>
"""
import glob
import os
import random
import sys
from PIL import Image

SRC, ART = sys.argv[1], sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.join(ART, "map"), exist_ok=True)
T = 19          # 한 칸 = 원본 19px (화면 x1 = 19px, x2 = 38px)
MX, MY = 16, 10 # 맵 바깥 숲 여백 (칸)


# ── 배치 ──

def walk(points):
    """꺾이는 점들을 이어 칸 목록으로"""
    out = [tuple(points[0])]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        dx = (x1 > x0) - (x1 < x0)
        dy = (y1 > y0) - (y1 < y0)
        x, y = x0, y0
        while (x, y) != (x1, y1):
            x += dx
            y += dy
            out.append((x, y))
    return out


def mirror(path, fx, fy, W, H):
    """거울. 가장자리에서 시작하던 길이 안쪽으로 밀리면 한 칸 이어 가장자리에 붙인다"""
    out = [((W - 2 - x) if fx else x, (H - 2 - y) if fy else y) for x, y in path]
    x, y = out[0]
    if fx and x == W - 2:
        out.insert(0, (W - 1, y))
    if fy and y == H - 2:
        out.insert(0, (x, H - 1))
    return out


def v2():
    W, H = 40, 24
    # 기획서: 입구는 왼쪽 6·17번째 줄 (y 5·16), 본부는 오른쪽 33번째 칸부터 (32..36, 8..12).
    # 새 입구는 바깥쪽 (y 1·21). 두 기본 길 사이 가운데 띠 (약 20x5) 가 합류 후보 지대
    a = walk([(0, 5), (6, 5), (6, 10), (12, 10), (12, 5), (31, 5), (31, 9)])
    b = walk([(0, 16), (8, 16), (8, 19), (16, 19), (16, 16), (31, 16), (31, 11)])
    c = walk([(0, 1), (36, 1), (36, 7)])
    d = walk([(0, 21), (36, 21), (36, 13)])
    return {
        "W": W, "H": H, "castle": (32, 8, 5, 5), "landmark": (4, 13, 3, 3),
        "base": [a, b], "extra": [c, d],
        "ponds": [(19, 7, 3, 2), (20, 18, 3, 2)],
        "rivers": [(3, 0, 2, 10), (27, 17, 2, 7)], "bridges": [(3, 1, 2, 1), (3, 5, 2, 1), (27, 21, 2, 1)],
        "high": [(13, 7, 3, 2), (20, 22, 3, 1), (26, 8, 2, 2), (37, 4, 2, 2)],
        "rocks": [(1, 11), (9, 2), (14, 13), (26, 13), (38, 10), (33, 19), (25, 23), (8, 23), (20, 3), (2, 19)],
        "old_roads": [(18, 13, 4, 1), (22, 7, 4, 1)],
        "cracks": [(6, 6), (6, 7), b[10], b[11], c[12], c[13], d[8], d[9]],
        "sand": [(9.5, 7.5), (12.5, 13.5), (26.5, 11.0), (20.5, 20.5), (2.5, 15.5), (38.5, 7.5)],
        "decor": [((2, 3), "barrel"), ((10, 3), "crate"), ((38, 14), "crate"), ((15, 12), "lamp"), ((26, 19), "lamp"),
                  ((37, 17), "container"), ((1, 18), "container")],
    }


def v4(players):
    W, H = 52, 30
    # 기획서: 입구는 왼쪽 4·12·20·28번째 줄 (y 3·11·19·27), 새 입구는 y 7·23. 본부는 오른쪽 (44..48, 13..17)
    l0 = walk([(0, 3), (14, 3), (14, 5), (46, 5), (46, 12)])
    l2 = walk([(0, 11), (10, 11), (10, 9), (20, 9), (20, 11), (30, 11), (30, 9), (38, 9), (38, 14), (43, 14)])
    l3 = walk([(0, 19), (10, 19), (10, 21), (20, 21), (20, 19), (30, 19), (30, 21), (38, 21), (38, 16), (43, 16)])
    l1 = walk([(0, 27), (14, 27), (14, 25), (46, 25), (46, 18)])
    e0 = walk([(0, 7), (44, 7), (44, 12)])
    e1 = walk([(0, 23), (44, 23), (44, 18)])
    base = [l0, l1, l2] if players == 3 else [l0, l1, l2, l3]
    extra = ([l3] if players == 3 else []) + [e0, e1]
    return {
        "W": W, "H": H, "castle": (44, 13, 5, 5), "landmark": (48, 2, 3, 3),
        "base": base, "extra": extra,
        "ponds": [(18, 13, 3, 2), (28, 15, 3, 2)],
        "rivers": [(5, 0, 2, 10), (5, 20, 2, 10)], "bridges": [(5, 3, 2, 1), (5, 7, 2, 1), (5, 23, 2, 1), (5, 27, 2, 1)],
        "high": [(14, 0, 3, 2), (24, 28, 3, 1), (40, 10, 2, 1), (10, 15, 3, 1)],
        "rocks": [(2, 5), (49, 7), (2, 24), (49, 23), (17, 13), (33, 18), (9, 15), (26, 13), (36, 1), (22, 29)],
        "old_roads": [(24, 14, 4, 1), (31, 17, 4, 1)],
        "cracks": [l0[12], l0[13], l1[12], l1[13], l2[16], l2[17], e0[20], e0[21]],
        "sand": [(15.5, 7.5), (39.5, 3.0), (15.5, 23.0), (39.5, 27.0), (25.5, 15.0), (9.5, 14.0)],
        "decor": [((1, 0), "barrel"), ((49, 10), "crate"), ((12, 29), "crate"), ((49, 20), "barrel"),
                  ((27, 15), "lamp"), ((37, 17), "lamp"), ((48, 26), "container"), ((1, 9), "container")],
    }


LAYOUTS = {"v2": v2(), "v3": v4(3), "v4": v4(4)}


def check(name, L):
    W, H = L["W"], L["H"]
    cx, cy, cw, ch = L["castle"]
    lanes = L["base"] + L["extra"]
    for i, p in enumerate(lanes):
        for (x0, y0), (x1, y1) in zip(p, p[1:]):
            assert abs(x0 - x1) + abs(y0 - y1) == 1, (name, i, "끊김", (x0, y0))
        sx, sy = p[0]
        assert sx in (0, W - 1) or sy in (0, H - 1), (name, i, "입구가 가장자리 아님", p[0])
        ex, ey = p[-1]
        assert any(abs(ex - x) + abs(ey - y) == 1 for x in range(cx, cx + cw) for y in range(cy, cy + ch)), (name, i, "본부 옆 아님", p[-1])
        assert len(set(p)) == len(p), (name, i, "겹침")
    for i in range(len(lanes)):
        for j in range(i + 1, len(lanes)):
            both = set(lanes[i]) & set(lanes[j])
            assert not both, (name, i, j, "길끼리 겹침", sorted(both)[:3])

    def inside(c, rects):
        return any(x <= c[0] < x + w and y <= c[1] < y + h for x, y, w, h in rects)
    for i, p in enumerate(lanes):
        for c in p:
            assert not inside(c, [L["landmark"]] + L["ponds"] + L["high"]), (name, i, "길이 지형 위", c)
            assert c not in L["rocks"], (name, i, "바위", c)
            if inside(c, L["rivers"]):
                assert inside(c, L["bridges"]), (name, i, "다리 아닌 강", c)
    print(name, "ok", [len(p) for p in lanes])


for n, L in LAYOUTS.items():
    check(n, L)


# ── maps.gd 내보내기 ──

def gd_cells(p):
    return "[" + ", ".join("Vector2i(%d, %d)" % c for c in p) + "]"


def gd_rects(rs):
    return "[" + ", ".join("Rect2i(%d, %d, %d, %d)" % r for r in rs) + "]"


lines = ["class_name MapData", "extends RefCounted",
         "## tools/make_maps.py 가 만든 파일 — 직접 고치지 말고 그 스크립트를 고친다.", "",
         "const ART_MARGIN := Vector2i(%d, %d)      # 지도 그림의 바깥 여백 (칸)" % (MX, MY), "",
         "static func get_layout(name: String) -> Dictionary:", "\tmatch name:"]
for n, L in LAYOUTS.items():
    lines.append('\t\t"%s":' % n)
    lines.append("\t\t\treturn {")
    lines.append('\t\t\t\t"W": %d, "H": %d,' % (L["W"], L["H"]))
    lines.append('\t\t\t\t"castle": Rect2i(%d, %d, %d, %d), "landmark": Rect2i(%d, %d, %d, %d),' % (L["castle"] + L["landmark"]))
    lines.append('\t\t\t\t"base": [%s],' % ", ".join(gd_cells(p) for p in L["base"]))
    lines.append('\t\t\t\t"extra": [%s],' % ", ".join(gd_cells(p) for p in L["extra"]))
    for k in ["ponds", "rivers", "bridges", "high", "old_roads"]:
        lines.append('\t\t\t\t"%s": %s,' % (k, gd_rects(L[k])))
    lines.append('\t\t\t\t"rocks": %s,' % gd_cells(L["rocks"]))
    lines.append('\t\t\t\t"cracks": %s,' % gd_cells(L["cracks"]))
    lines.append('\t\t\t\t"sand": [%s],' % ", ".join("Vector2(%s, %s)" % s for s in L["sand"]))
    lines.append("\t\t\t}")
lines.append("\treturn {}")
open(os.path.join(ROOT, "scripts", "sim", "maps.gd"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")


# ── 그림 ──

def load(prefix):
    return Image.open(glob.glob(os.path.join(SRC, prefix + "*.png"))[0]).convert("RGBA")


def shrink(im, k):
    return im.resize((im.width // k, im.height // k), Image.NEAREST)


def unbg(im, keys=None):
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
    cell = unbg(lm.crop((i * 60, 0, i * 60 + 58, 56)))
    landmarks.append(cell.crop(cell.getbbox()))
deco = shrink(load("f0a1c914e8"), 3)
DECO = ["tree", "rock", "crate", "barrel", "lamp", "container"]
decor = {}
for col in range(4):
    for row, name in enumerate(DECO):
        cell = unbg(deco.crop((col * 40, row * 30, col * 40 + 38, row * 30 + 28)))
        bb = cell.getbbox()
        decor[(col, name)] = cell.crop(bb) if bb else cell

PAL = {
    "grass": [(78, 90, 54), (86, 99, 59), (72, 83, 48), (134, 130, 122), (146, 142, 133), (176, 138, 52), (74, 71, 64), (34, 48, 26), (47, 66, 36), (63, 86, 48)],
    "snow": [(198, 207, 211), (210, 218, 221), (184, 194, 199), (138, 148, 154), (151, 160, 165), (176, 138, 52), (85, 96, 106), (30, 44, 51), (42, 61, 70), (58, 82, 96)],
    "sand": [(176, 149, 106), (188, 161, 118), (160, 134, 96), (110, 104, 95), (122, 116, 106), (196, 156, 54), (62, 58, 52), (52, 68, 42), (70, 88, 58), (90, 112, 72)],
    "lava": [(46, 41, 38), (54, 48, 44), (38, 34, 32), (78, 72, 68), (90, 83, 78), (196, 106, 42), (26, 23, 22), (26, 23, 22), (38, 33, 30), (51, 44, 40)],
    "ghost": [(39, 53, 47), (46, 62, 55), (33, 45, 40), (90, 96, 88), (102, 109, 100), (111, 168, 148), (30, 34, 31), (15, 26, 22), (23, 42, 35), (33, 57, 47)],
}
POND = {"grass": (64, 104, 118), "snow": (168, 196, 210), "sand": (150, 124, 88), "lava": (196, 96, 40), "ghost": (34, 60, 62)}
RIVER = {"grass": (52, 92, 110), "snow": (150, 182, 198), "sand": (66, 106, 120), "lava": (176, 78, 34), "ghost": (30, 54, 58)}
THEME_COL = {"grass": 0, "snow": 1, "sand": 2, "lava": 3, "ghost": 0}
THEMES = ["grass", "snow", "sand", "lava", "ghost"]
OUTLINE = (14, 13, 12, 255)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def ghostly(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.55), int(g * 0.75), int(b * 0.7), a)
    return im


def put(img, spr, bx, by):
    img.alpha_composite(spr, (int(bx - spr.width // 2), int(by - spr.height)))


def stepped_rect(bp, x0, y0, x1, y1, fill, edge, cut=3):
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = min(y - y0, y1 - 1 - y)
            d = min(x - x0, x1 - 1 - x)
            if d + c < cut:
                continue
            e = min(d, c) == 0 or d + c == cut
            bp[x, y] = (edge if e else fill) + (255,)


for lname, L in LAYOUTS.items():
    W, H = L["W"], L["H"]
    size = ((W + 2 * MX) * T, (H + 2 * MY) * T)
    ox, oy = MX * T, MY * T
    gw, gh = W * T, H * T
    for ti, theme in enumerate(THEMES):
        P = PAL[theme]
        rnd = random.Random(11 + ti)
        base = Image.new("RGBA", size, shade(P[2], 0.82) + (255,))
        bp = base.load()
        for _ in range(size[0] * size[1] // 18):
            x, y = rnd.randrange(size[0]), rnd.randrange(size[1])
            bp[x, y] = shade(P[rnd.randrange(3)], 0.78) + (255,)
        inner = (ox - 6, oy - 6, ox + gw + 6, oy + gh + 6)
        for y in range(inner[1], inner[3]):
            for x in range(inner[0], inner[2]):
                bp[x, y] = P[0] + (255,)
        for ty in range(-1, H + 1):
            for tx in range(-1, W + 1):
                for _ in range(rnd.randint(1, 2)):
                    x = ox + tx * T + rnd.randint(2, T - 4)
                    y = oy + ty * T + rnd.randint(3, T - 3)
                    if not (inner[0] <= x < inner[2] - 2 and inner[1] + 2 <= y < inner[3]):
                        continue
                    if rnd.random() < 0.7:
                        c4 = shade(P[2], 0.86)
                        bp[x, y] = c4 + (255,)
                        bp[x + 1, y - 1] = c4 + (255,)
                        bp[x + 2, y] = c4 + (255,)
                    else:
                        bp[x, y] = shade(P[1], 1.18) + (255,)
                        bp[x + 1, y] = shade(P[2], 0.8) + (255,)
        # 높은 땅: 밝은 판 + 아래·오른쪽 그림자 2픽셀 (빛은 왼쪽 위)
        for (hx, hy, hw, hh) in L["high"]:
            x0, y0, x1, y1 = ox + hx * T, oy + hy * T, ox + (hx + hw) * T, oy + (hy + hh) * T
            top = shade(P[1], 1.12)
            for y in range(y0, y1):
                for x in range(x0, x1):
                    bp[x, y] = top + (255,)
            for x in range(x0, x1):
                bp[x, y0] = shade(top, 1.15) + (255,)
                for k in range(3):
                    bp[x, y1 - 1 - k] = shade(P[2], 0.62 + k * 0.08) + (255,)
            for y in range(y0, y1):
                bp[x1 - 1, y] = shade(P[2], 0.65) + (255,)
                bp[x0, y] = shade(top, 1.15) + (255,)
            for k in range((x1 - x0) // 6):      # 판 위 줄눈
                bp[x0 + 3 + k * 6, y0 + 4] = shade(top, 0.9) + (255,)
        # 강: 진한 물 + 물결, 다리는 판자
        for (rx, ry, rw, rh) in L["rivers"]:
            x0, y0, x1, y1 = ox + rx * T, oy + ry * T, ox + (rx + rw) * T, oy + (ry + rh) * T
            for y in range(y0, y1):
                for x in range(x0, x1):
                    edge = x in (x0, x1 - 1)
                    bp[x, y] = (shade(RIVER[theme], 0.62) if edge else RIVER[theme]) + (255,)
            for k in range((y1 - y0) // 9):
                wy = y0 + 4 + k * 9
                wx = x0 + 4 + (k % 2) * 10
                for x in range(wx, min(wx + 6, x1 - 3)):
                    bp[x, wy] = shade(RIVER[theme], 1.35) + (255,)
        for (bx_, by_, bw_, bh_) in L["bridges"]:
            x0, y0, x1, y1 = ox + bx_ * T, oy + by_ * T, ox + (bx_ + bw_) * T, oy + (by_ + bh_) * T
            for y in range(y0 - 2, y1 + 2):
                for x in range(x0, x1):
                    plank = (x - x0) % 4 == 3
                    edge = y in (y0 - 2, y1 + 1)
                    bp[x, y] = ((60, 44, 30) if edge else ((96, 70, 44) if plank else (132, 98, 60))) + (255,)
        for (px_, py_, pw, ph) in L["ponds"]:
            x0, y0 = ox + px_ * T + 2, oy + py_ * T + 2
            x1, y1 = ox + (px_ + pw) * T - 2, oy + (py_ + ph) * T - 2
            stepped_rect(bp, x0, y0, x1, y1, POND[theme], shade(POND[theme], 0.6))
            for i in range(3):
                wy = y0 + (y1 - y0) * (i + 1) // 4
                wx = x0 + 8 + (i % 2) * 14
                for x in range(wx, min(wx + 5, x1 - 3)):
                    bp[x, wy] = shade(POND[theme], 1.3) + (255,)
        over = Image.new("RGBA", size, (0, 0, 0, 0))
        stand = []
        col = THEME_COL[theme]

        def deco_(name):
            spr = decor[(col, name)]
            return ghostly(spr) if theme == "ghost" else spr

        def outside(x, y):
            return not (inner[0] - 10 < x < inner[2] + 10 and inner[1] - 2 < y < inner[3] + 16)

        for _ in range(size[0] * size[1] // 520):
            x, y = rnd.randrange(-8, size[0] + 8), rnd.randrange(0, size[1] + 20)
            if outside(x, y):
                stand.append((y, deco_("tree"), x))
        for _ in range(size[0] * size[1] // 9000):
            x, y = rnd.randrange(0, size[0]), rnd.randrange(0, size[1])
            if outside(x, y):
                stand.append((y, deco_("rock"), x))
        for (cx, cy) in L["rocks"]:
            stand.append((oy + (cy + 1) * T - 2, deco_("rock"), ox + cx * T + T // 2))
        for (cx, cy), name in L["decor"]:
            bx = ox + cx * T + (T if name == "container" else T // 2)
            stand.append((oy + (cy + 1) * T - 2, deco_(name), bx))
        # 본부는 체력 단계에 따라 게임이 art/hq.png 로 그린다
        lx, ly, _, _ = L["landmark"]
        stand.append((oy + (ly + 3) * T - 1, landmarks[ti], ox + (lx + 1.5) * T))
        opened = L["base"] + L["extra"][:ti]      # 테마마다 입구가 하나씩 더 열린다
        for i, p in enumerate(opened):
            gx, gy = p[0]
            g = gates[min(i, 4)]
            if gx == 0:
                bx, by = ox + 3, oy + gy * T + 1
            elif gx == W - 1:
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
    print(lname, size)
