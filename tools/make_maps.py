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
    a = walk([(0, 4), (6, 4), (6, 9), (12, 9), (12, 4), (17, 4), (17, 12), (18, 12)])
    b = walk([(39, 19), (33, 19), (33, 14), (28, 14), (28, 19), (23, 19), (23, 12), (22, 12)])
    c = walk([(28, 0), (28, 3), (24, 3), (24, 8), (20, 8), (20, 10)])
    d = walk([(11, 23), (11, 19), (15, 19), (15, 15), (20, 15), (20, 14)])
    return {
        "W": W, "H": H, "castle": (19, 11, 3, 3), "landmark": (4, 12, 3, 3),
        "base": [a, b], "extra": [c, d],
        "ponds": [(31, 7, 3, 3), (7, 15, 3, 3)],
        "rivers": [(3, 0, 2, 9), (35, 15, 2, 9)], "bridges": [(3, 4, 2, 1), (35, 19, 2, 1)],
        "high": [(13, 6, 3, 2), (29, 16, 3, 2), (25, 4, 2, 3), (16, 16, 3, 2)],
        "rocks": [(1, 10), (9, 1), (14, 13), (26, 11), (37, 4), (30, 21), (22, 22), (8, 21), (33, 1), (2, 20)],
        "old_roads": [(25, 10, 4, 1), (12, 13, 4, 1)],
        "cracks": [(6, 5), (6, 6), (33, 16), (33, 17), (24, 5), (24, 6), (15, 17), (15, 18)],
        "sand": [(9.5, 6.5), (30.5, 17.5), (25.5, 6.0), (13.5, 17.5), (8.5, 20.5), (31.5, 3.5)],
        "decor": [((2, 2), "barrel"), ((10, 2), "crate"), ((30, 12), "crate"), ((15, 8), "lamp"), ((25, 17), "lamp"),
                  ((37, 9), "container"), ((1, 16), "container")],
    }


def v4(players):
    W, H = 52, 30
    p1 = walk([(0, 5), (8, 5), (8, 10), (15, 10), (15, 4), (20, 4), (20, 13), (23, 13)])
    p2 = mirror(p1, True, False, W, H)
    p3 = mirror(p1, False, True, W, H)
    p4 = mirror(p1, True, True, W, H)
    top = walk([(25, 0), (25, 2), (23, 2), (23, 7), (27, 7), (27, 10), (25, 10), (25, 12)])
    bottom = mirror(top, False, True, W, H)
    base = [p1, p2, p3] if players == 3 else [p1, p2, p3, p4]
    extra = ([p4] if players == 3 else []) + [top, bottom]
    return {
        "W": W, "H": H, "castle": (24, 13, 3, 3), "landmark": (6, 13, 3, 3),
        "base": base, "extra": extra,
        "ponds": [(2, 13, 3, 3), (46, 13, 3, 3)],
        "rivers": [(43, 0, 2, 11), (5, 18, 2, 12)], "bridges": [(43, 5, 2, 1), (5, 23, 2, 1)],
        "high": [(10, 6, 3, 2), (38, 6, 3, 2), (10, 21, 3, 2), (38, 21, 3, 2)],
        "rocks": [(2, 2), (49, 2), (2, 27), (49, 27), (17, 15), (33, 15), (12, 14), (38, 14), (30, 1), (20, 28)],
        "old_roads": [(16, 14, 4, 1), (31, 14, 4, 1)],
        "cracks": [(8, 6), (8, 7), (42, 6), (42, 7), (8, 21), (8, 22), (42, 21), (42, 22)],
        "sand": [(11.5, 8.0), (39.5, 8.0), (11.5, 21.0), (39.5, 21.0), (18.5, 14.5), (32.5, 14.5)],
        "decor": [((12, 1), "barrel"), ((38, 1), "crate"), ((12, 27), "crate"), ((38, 27), "barrel"),
                  ((21, 9), "lamp"), ((29, 19), "lamp"), ((45, 26), "container"), ((1, 9), "container")],
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
        cx, cy, _, _ = L["castle"]
        stand.append((oy + (cy + 3) * T, castle, ox + (cx + 1.5) * T))
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
