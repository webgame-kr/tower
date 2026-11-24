// 개편 맵(2인 21x13, 3~4인 25x15) 시안의 테마별 지형을 두 장의 이미지로 뽑는다.
//   <layout>_<id>_base.png : 지면·바위·연못·막힌 땅 (길 아래)
//   <layout>_<id>_over.png : 랜드마크·본부·입구 (길 위)
// 길, 효과 표시(점선), 입구 번호판은 게임이 판정 데이터로 직접 그리므로 뺀다.
// 사용: node tools/extract_map2.js <시안 project 폴더> <임시 폴더> <출력 폴더>
const fs = require("fs"), path = require("path"), { spawnSync } = require("child_process");
const [, , P, TMP, OUT] = process.argv;
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const IDS = ["grass", "snow", "sand", "lava", "ghost"];
// file, layout, 시안 칸 크기, 시안 격자 시작, 게임 칸 크기, 게임 격자 시작
const SETS = [
  ["MapV2Themes.dc.html", "v2", 24, [26, 24], 36, [262, 110]],
  ["MapV4Themes.dc.html", "v4", 20, [33, 23], 30, [265, 115]],
];
const W = 1600, H = 900, SCALE = W / 1280;

function children(x) {
  const out = [];
  let d = 0, start = -1, m;
  const re = /<(\/?)([a-zA-Z]+)\b[^>]*?(\/?)>/g;
  while ((m = re.exec(x))) {
    if (m[1]) { d--; if (d === 0) out.push(x.slice(start, m.index + m[0].length)); }
    else if (!m[3]) { if (d === 0) start = m.index; d++; }
    else if (d === 0) out.push(m[0]);
  }
  return out;
}
const inner = (s) => s.slice(s.indexOf(">") + 1, s.lastIndexOf("</svg>"));

function shot(html, png, w, h) {
  try { fs.unlinkSync(png); } catch (e) {}
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--default-background-color=00000000", "--user-data-dir=" + path.join(TMP, "prof"), `--window-size=${w},${h}`,
    "--screenshot=" + png, "file:///" + html.split(path.sep).join("/")], { stdio: "ignore", timeout: 60000 });
  return fs.existsSync(png);
}

fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(TMP, { recursive: true });
const meta = {};
for (const [file, layout, cs, o, gc, go] of SETS) {
  const svgs = fs.readFileSync(path.join(P, file), "utf8").match(/<svg viewBox=[\s\S]*?<\/svg>/g).filter((x) => x.length > 20000);
  const K = gc / cs;
  const vb = [o[0] - go[0] / K, o[1] - go[1] / K, 1280 / K, 720 / K];
  const size = svgs[0].match(/viewBox="0 0 (\d+) (\d+)"/);
  meta[layout] = { w: +size[1], h: +size[2], K, o, go };
  svgs.slice(0, 5).forEach((svg, ti) => {
    const id = IDS[ti];
    const top = children(inner(svg));
    const defs = top.filter((k) => k.startsWith("<defs")).join("");
    const g = top.find((k) => k.startsWith("<g clip"));
    const kids = children(g.slice(g.indexOf(">") + 1, g.lastIndexOf("</g>")));
    const grid = kids.findIndex((k) => /^<path d="M[\d.]+ [\d.]+ V[\d.]+ M/.test(k));
    const isRoad = (k) => /^<path d="M[\d.]+ [\d.]+ (L[\d.]+ [\d.]+ ){4,}/.test(k) && /fill="none"/.test(k.slice(0, k.indexOf(">")));
    const isArrow = (k) => /^<g transform="translate\([\d. ]+\) rotate\(-?\d+\) scale\(0\./.test(k);
    const first = kids.findIndex((k, i) => i > grid && isRoad(k));
    let last = first;
    kids.forEach((k, i) => { if (i > grid && (isRoad(k) || isArrow(k))) last = i; });
    const dashed = (k) => /stroke-dasharray/.test(k.slice(0, k.indexOf(">")));
    const badge = (k) => k.startsWith("<g") && k.includes('d="M-20 -13 H20 L24 0');
    const base = kids.slice(0, grid).concat(kids.slice(grid + 1, first).filter((k) => !dashed(k)));
    const over = kids.slice(last + 1).filter((k) => !badge(k) && !k.includes("<text"));
    for (const [suffix, body] of [["base", base], ["over", over]]) {
      const html = path.join(TMP, `${layout}_${id}_${suffix}.html`);
      fs.writeFileSync(html, `<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent;width:${W}px;height:${H}px;overflow:hidden}</style>` +
        `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.join(" ")}" width="${W}" height="${H}">${defs}${suffix === "base" ? `<svg x="0" y="0" width="${meta[layout].w}" height="${meta[layout].h}" viewBox="0 0 ${meta[layout].w} ${meta[layout].h}">${body.join("")}</svg>` : body.join("")}</svg>`);
      const png = path.join(OUT, `${layout}_${id}_${suffix}.png`);
      console.log(layout, id, suffix, shot(html, png, W, H) ? fs.statSync(png).size : "FAILED");
    }
  });
}
// 바깥을 거울로 채울 때 쓸 시안 그림의 화면 위치 (1600x900 기준)
const box = {};
for (const k in meta) {
  const m = meta[k];
  box[k] = [(m.go[0] - m.o[0] * m.K) * SCALE, (m.go[1] - m.o[1] * m.K) * SCALE, m.w * m.K * SCALE, m.h * m.K * SCALE].map((v) => Math.round(v));
}
fs.writeFileSync(path.join(TMP, "boxes.json"), JSON.stringify(box));
console.log("BOX", JSON.stringify(box));
