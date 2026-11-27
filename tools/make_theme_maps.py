# 새 테마 지도 그림: 기존 테마 그림을 색만 바꿔 만든다 (늪 ← 초원, 폭풍 ← 설원, 고철 ← 사막)
# 사용: python3 tools/make_theme_maps.py
import colorsys, os
from PIL import Image
ART = os.path.join(os.path.dirname(__file__), "..", "art", "map")


def remap(src, fn):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            if c not in cache:
                r, g, b = [v / 255 for v in c[:3]]
                h, s, v = colorsys.rgb_to_hsv(r, g, b)
                h, s, v = fn(h * 360, s, v)
                rr, gg, bb = colorsys.hsv_to_rgb((h % 360) / 360, max(0, min(1, s)), max(0, min(1, v)))
                cache[c] = (round(rr * 255), round(gg * 255), round(bb * 255), c[3])
            px[x, y] = cache[c]
    return im


def bog(h, s, v):
    if 170 < h < 230 and s > 0.25:          # 물 → 탁한 늪물
        return 70, s * 0.7, v * 0.75
    if 60 < h < 140:                          # 풀 → 올리브 갈색
        return h - 28, s * 0.85, v * 0.82
    return h, s * 0.85, v * 0.88


def storm(h, s, v):
    if 170 < h < 230 and s > 0.15:
        return 215, s * 0.6, v * 0.55
    return 220, s * 0.35 + 0.06, v * 0.52


def scrap(h, s, v):
    if 170 < h < 230 and s > 0.25:          # 물 → 기름 섞인 물
        return 195, s * 0.5, v * 0.6
    if 25 < h < 60:                           # 모래 → 녹슨 흙
        return h - 14, s * 0.8, v * 0.62
    return h - 8, s * 0.8, v * 0.7


for lay in ("v2", "v3", "v4"):
    for src, dst, fn in (("grass", "bog", bog), ("snow", "storm", storm), ("sand", "scrap", scrap)):
        for part in ("base", "over"):
            p = os.path.join(ART, "%s_%s_%s.png" % (lay, src, part))
            if os.path.exists(p):
                remap(p, fn).save(os.path.join(ART, "%s_%s_%s.png" % (lay, dst, part)))
print("ok")
