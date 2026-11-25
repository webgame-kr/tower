"""모션 꾸러미(tower-motion-sfx2.zip 을 푼 폴더)에서 게임용 그림을 만든다.
- art/towers_dir.png : 8방향 무기형 포탑 9종 (한 칸 48x48, 줄 = 종류, 칸 = (단계*4 + 주인 색)*8 + 방향)
- art/enemies_dir.png: 적 6종 (한 칸 56x44, 종류마다 3줄: 남·북·동, 서는 동을 뒤집음, 칸 0-3 걷기 · 4 피격 · 5-7 쓰러짐)
- art/hq_anim.png    : 본부 대기·피격·단계 (한 칸 128x152, 줄마다 8칸)
- art/react.png      : 반응 12종 터짐 (한 칸 64x56, 줄 = 반응)
- scripts/dirdata.gd : 포탑 총구 자리, 발 자리, 본부 그림 맞춤
사용: python tools/make_motion.py <꾸러미 폴더>
"""
import json
import os
import sys
from PIL import Image

SRC = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")

DIR_TYPES = [("gun", "gun"), ("cannon", "cannon"), ("cold", "frost"), ("magnet", "magnet"), ("oil", "oil"),
             ("flame", "fire"), ("sniper", "sniper"), ("signal", "signal"), ("searchlight", "searchlight")]
LVS = ["lv1", "lv2", "lv3a", "lv3b"]
COLS = ["r", "b", "y", "g"]
ENEMY = ["grunt", "runner", "armor", "swarm", "healer", "boss"]       # 게임의 look 번호 순서
HQ = ["hq_hq_idle", "hq_hq_hit", "hq_hq_stage"]
RX = [("ignite", "ignite"), ("harden", "lock"), ("short", "short"), ("thermal", "thermal"), ("super", "supercond"), ("brittle", "brittle"),
      ("emag", "emag"), ("melt", "heatarmor"), ("overheat", "overheat"), ("shatter", "shatter"), ("slip", "slip"), ("amp", "amplify")]

d = json.load(open(os.path.join(SRC, "directions.json"), encoding="utf-8"))

# 포탑
FW = 48
tw = Image.new("RGBA", (16 * 8 * FW, len(DIR_TYPES) * FW), (0, 0, 0, 0))
for row, (game, pkg) in enumerate(DIR_TYPES):
    for li, lv in enumerate(LVS):
        for ci, col in enumerate(COLS):
            sheet = Image.open(os.path.join(SRC, "art", "dir", "tower_%s_%s_%s.png" % (pkg, lv, col))).convert("RGBA")
            assert sheet.size == (8 * FW, FW), sheet.size
            tw.paste(sheet, ((li * 4 + ci) * 8 * FW, row * FW))
tw.save(os.path.join(ART, "towers_dir.png"))

# 적
ew, eh = 56, 44
en = Image.new("RGBA", (8 * ew, len(ENEMY) * 3 * eh), (0, 0, 0, 0))
bottoms = []
for i, name in enumerate(ENEMY):
    sheet = Image.open(os.path.join(SRC, "art", "dir", "enemy_%s.png" % name)).convert("RGBA")
    en.paste(sheet, (0, i * 3 * eh))
    bb = sheet.crop((0, 0, ew, eh)).getbbox()
    bottoms.append(bb[3])
en.save(os.path.join(ART, "enemies_dir.png"))

# 본부
hw, hh = 128, 152
hq = Image.new("RGBA", (8 * hw, len(HQ) * hh), (0, 0, 0, 0))
for i, name in enumerate(HQ):
    hq.paste(Image.open(os.path.join(SRC, "art", "fx", name + ".png")).convert("RGBA"), (0, i * hh))
hq.save(os.path.join(ART, "hq_anim.png"))
idle0 = hq.crop((0, 0, hw, hh)).getbbox()
mine = Image.open(os.path.join(ART, "hq.png")).convert("RGBA").crop((0, 0, 104, 136)).getbbox()
# 꾸러미 본부의 아래·가운데를 지금 본부 그림의 아래·가운데에 맞춘다
hq_off = (((mine[0] + mine[2]) - (idle0[0] + idle0[2])) // 2, mine[3] - idle0[3])

# 반응
rw, rh = 64, 56
rx = Image.new("RGBA", (8 * rw, len(RX) * rh), (0, 0, 0, 0))
for i, (_, pkg) in enumerate(RX):
    sheet = Image.open(os.path.join(SRC, "art", "fx", "react_%s.png" % pkg)).convert("RGBA")
    base = sheet.crop((0, 0, rw, rh)).load()
    for f in range(8):      # 첫 칸(그냥 적)과 같은 픽셀과 위쪽 이름표를 지워 터짐만 남긴다
        fr = sheet.crop((f * rw, 0, (f + 1) * rw, rh))
        px = fr.load()
        for y in range(rh):
            for x in range(rw):
                if y < 13 or px[x, y] == base[x, y]:
                    px[x, y] = (0, 0, 0, 0)
        rx.paste(fr, (f * rw, i * rh))
rx.save(os.path.join(ART, "react.png"))

# 총구 자리
lines = ["class_name DirData", "extends RefCounted",
         "## tools/make_motion.py 가 만든 파일 — 직접 고치지 말고 그 스크립트를 고친다.", "",
         "const TOWER_ROW := {%s}" % ", ".join('"%s": %d' % (g, i) for i, (g, _) in enumerate(DIR_TYPES)),
         "const FOOT := Vector2(%d, %d)      # 포탑 한 칸 48x48 의 발" % tuple(d["tower"]["gun"]["foot"]),
         "const ENEMY_FOOT := [%s]      # 적 종류별 발 높이 (한 칸 56x44)" % ", ".join(str(b) for b in bottoms),
         "const HQ_OFF := Vector2(%d, %d)      # 본부 움직임 그림(128x152) 을 지금 그림(104x136) 자리에 맞추는 어긋남" % hq_off,
         "const RX_ROW := {%s}" % ", ".join('"%s": %d' % (g, i) for i, (g, _) in enumerate(RX)),
         "const MUZZLE := {"]
DIRS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
for game, pkg in DIR_TYPES:
    mz = d["tower"][pkg]["muzzle"]
    rows = []
    for lv in LVS:
        rows.append("[%s]" % ", ".join("Vector2(%d, %d)" % tuple(mz[lv][k]) for k in DIRS))
    lines.append('\t"%s": [%s],' % (game, ", ".join(rows)))
lines.append("}")
open(os.path.join(ROOT, "scripts", "dirdata.gd"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("ok", tw.size, en.size, "foot", bottoms, "hq_off", hq_off)
