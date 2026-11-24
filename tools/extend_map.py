"""시안 지형은 1280x720 보다 좁으므로, 바깥 풍경을 거울처럼 이어 붙여 화면 전체를 채운다.
사용: python tools/extend_map.py art/map"""
import glob
import os
import sys

from PIL import Image, ImageOps

folder = sys.argv[1]
K = 28 / 15 * 1.25
LEFT = int(round((75.5 * -1 + 262 / (28 / 15) + 0) * K)) + 1      # 시안 그림의 왼쪽 끝
TOP = int(round((-43 + 100 / (28 / 15)) * K)) + 1
RIGHT = LEFT + int(556 * K) - 2
BOTTOM = TOP + int(350 * K) - 2

for path in glob.glob(os.path.join(folder, "*_base.png")):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    inner = im.crop((LEFT, TOP, RIGHT, BOTTOM))
    out = Image.new("RGB", (W, H))
    out.paste(inner, (LEFT, TOP))
    out.paste(ImageOps.mirror(inner.crop((0, 0, LEFT, inner.height))), (0, TOP))
    right = W - RIGHT
    out.paste(ImageOps.mirror(inner.crop((inner.width - right, 0, inner.width, inner.height))), (RIGHT, TOP))
    row = out.crop((0, TOP, W, BOTTOM))
    out.paste(ImageOps.flip(row.crop((0, 0, W, TOP))), (0, 0))
    below = H - BOTTOM
    out.paste(ImageOps.flip(row.crop((0, row.height - below, W, row.height))), (0, BOTTOM))
    out.save(path, optimize=True)
    print(os.path.basename(path), out.size, os.path.getsize(path))
