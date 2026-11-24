"""시안 지형은 화면보다 좁으므로, 바깥 풍경을 거울처럼 이어 붙여 화면 전체를 채운다.
사용: python tools/extend_map2.py <폴더> '{"v2":[x,y,w,h],...}'   (extract_map2.js 가 알려 준 BOX)"""
import glob
import json
import os
import sys

from PIL import Image, ImageOps

folder = sys.argv[1]
boxes = json.loads(sys.argv[2])
for path in glob.glob(os.path.join(folder, "*_base.png")):
    layout = os.path.basename(path).split("_")[0]
    x, y, w, h = boxes[layout]
    LEFT, TOP, RIGHT, BOTTOM = x + 2, y + 2, x + w - 2, y + h - 2
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
