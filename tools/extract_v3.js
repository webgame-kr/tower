// 비주얼 v3 시안에서 게임 그림을 뽑는다.
//   art/map/<v2|v4>_<테마>_base.png : 바깥 숲·땅·장식 (길 아래)
//   art/map/<v2|v4>_<테마>_over.png : 서 있는 것 (나무·장식·입구·본부·랜드마크, 길 위)
//   art/towers.png  : 포탑 10종 x (MK-1, MK-2, MK-3A, MK-3B) x 주인 색 4, 한 칸 120x168 (칸 0..100 기준, 위로 64)
//   art/enemies.png : 적 6종 한 칸 128x128 (적 좌표 -14..114)
//   art/gate.png    : 입구 경고등 기둥 (새로 열리는 입구용)
// 길·격자·포탑·적·효과는 게임이 직접 그리므로 지도 그림에서 뺀다.
// 사용: node tools/extract_v3.js <시안 project 폴더> <임시 폴더> <art 폴더>
const fs = require("fs"), path = require("path"), { spawnSync } = require("child_process");
const [, , P, TMP, ART] = process.argv;
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const W = 1600, H = 900, S = W / 1280;
const OWNER = ["#E0533D", "#3D6FD1", "#E9B935", "#38A672"];
fs.mkdirSync(TMP, { recursive: true });
fs.mkdirSync(path.join(ART, "map"), { recursive: true });

const read = (f) => fs.readFileSync(path.join(P, f), "utf8");
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
// n 번째로 나오는 viewBox 의 svg 전체 (중첩 svg 포함)
function svgAt(s, vb, n = 0) {
  let at = -1;
  for (let i = 0; i <= n; i++) at = s.indexOf('<svg viewBox="' + vb + '"', at + 1);
  if (at < 0) return null;
  const re = /<(\/?)svg\b[^>]*>/g;
  re.lastIndex = at;
  let m, depth = 0;
  while ((m = re.exec(s))) {
    if (m[1]) { depth--; if (depth === 0) return s.slice(at, m.index + 6); } else depth++;
  }
  return null;
}
const inner = (svg) => svg.slice(svg.indexOf(">") + 1, svg.lastIndexOf("</svg>"));
function shot(name, body, w, h) {
  const html = path.join(TMP, name + ".html");
  const png = path.join(TMP, name + ".png");
  fs.writeFileSync(html, `<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent;width:${w}px;height:${h}px;overflow:hidden}</style>${body}`);
  try { fs.unlinkSync(png); } catch (e) {}
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars", "--force-device-scale-factor=1", "--default-background-color=00000000",
    "--user-data-dir=" + path.join(TMP, "prof"), `--window-size=${w},${h}`, "--screenshot=" + png, "file:///" + html.split(path.sep).join("/")], { stdio: "ignore", timeout: 90000 });
  if (!fs.existsSync(png)) throw new Error("render failed " + name);
  return png;
}

// ── 지도: 바닥과 서 있는 것 나누기 ──
const isGrid = (k) => /^<path d="M[\d.]+ [\d.]+ h6 M/.test(k);
const isRoad = (k) => /^<path d="M-?[\d.]+ [\d.]+ (L-?[\d.]+ [\d.]+ ?){4,}/.test(k) && /fill="none"/.test(k.slice(0, k.indexOf(">")));
const isArrow = (k) => /^<g transform="translate\([-\d. ]+\) rotate\(-?\d+\)( scale\([\d.]+\))?">/.test(k) && k.length < 400;
const isTower = (k) => k.includes("translate(50 92) scale(1.22)");
const isEnemy = (k) => k.startsWith("<g") && k.includes('cx="52.0" cy="88.0"');
const isFx = (k) => /^<(g|circle|path)[^>]*stroke-dasharray/.test(k) ||  /stroke-dasharray/.test(k.slice(0, 400)) || /fill="#(ffe08a|ffb347|FFE08A|FFB347)"/.test(k.slice(0, 200)) || /scale\(0\.(727|9)\)/.test(k.slice(0, 80));
function split(svg) {
  const kids = children(inner(svg));
  const g = kids.findIndex(isGrid);
  let road = kids.findIndex((k, i) => i > g && isRoad(k));
  const base = kids.slice(0, road >= 0 ? Math.min(g, road) : g).filter((k) => !isFx(k) && !isTower(k) && !isEnemy(k));
  const over = kids.slice(g + 1).filter((k) => !isRoad(k) && !isArrow(k) && !isTower(k) && !isEnemy(k) && !isFx(k));
  return { base, over };
}
function mapPngs(layout, id, svg, vb, k, o, go) {
  // vb: 시안 svg 의 크기, o: 시안 격자 시작, k: 게임 칸 / 시안 칸, go: 게임 격자 시작
  const { base, over } = split(svg);
  const view = [o[0] - go[0] / k, o[1] - go[1] / k, 1280 / k, 720 / k];
  const wrap = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${view.join(" ")}" width="${W}" height="${H}"><svg x="0" y="0" width="${vb[0]}" height="${vb[1]}" viewBox="0 0 ${vb[0]} ${vb[1]}" overflow="hidden">${body}</svg></svg>`;
  for (const [part, body] of [["base", base], ["over", over]]) {
    const png = shot(`${layout}_${id}_${part}`, wrap(body.join("")), W, H);
    fs.copyFileSync(png, path.join(ART, "map", `${layout}_${id}_${part}.png`));
  }
  const box = [(go[0] - o[0] * k) * S, (go[1] - o[1] * k) * S, vb[0] * k * S, vb[1] * k * S].map(Math.round);
  console.log(layout, id, "base", base.length, "over", over.length, "box", box.join(","));
  return box;
}

// 2인 합류 맵: 칸 38, 격자 시작 (221,112). 초원·설원·사막은 전체 화면 시안, 화산·유령 숲은 테마 보드
const boxes = {};
const full = [["grass", "Battle.dc.html"]];      // 설원·사막 전체 화면 시안에는 미리보기·핑 휠이 섞여 있어 테마 보드를 쓴다
for (const [id, f] of full) boxes["v2_" + id] = mapPngs("v2", id, svgAt(read(f), "0 0 1280 720"), [1280, 720], 1, [221, 112], [221, 112]);
const themes = read("Themes.dc.html");
for (const [i, id] of [[1, "snow"], [2, "sand"], [3, "lava"], [4, "ghost"]]) boxes["v2_" + id] = mapPngs("v2", id, svgAt(themes, "0 0 566 360", i), [566, 360], 38 / 24, [31, 34], [221, 112]);

// 3~4인 네 갈래 맵: 칸 30, 격자 시작 (265,115). 초원은 큰 시안, 유령 숲은 작은 시안, 나머지는 초원 색을 바꿔서
const map4 = read("Map4.dc.html");
const big = svgAt(map4, "0 0 1168 700");
const THEME = {      // 테마 팔레트: 바깥 배경, 땅 (시안 v3-00)
  snow: { bg: "#1B2630", ground: "#D9E4EA" },
  sand: { bg: "#33261A", ground: "#D2B27A" },
  lava: { bg: "#120D0C", ground: "#3A332F" },
};
function hsl(hex) {
  const n = parseInt(hex.slice(1), 16), r = (n >> 16) / 255, g = ((n >> 8) & 255) / 255, b = (n & 255) / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  let h = 0, s = 0;
  if (mx !== mn) {
    const d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h *= 60;
  }
  return [h, s, l];
}
function hex([h, s, l]) {
  const f = (n) => { const k = (n + h / 30) % 12, a = s * Math.min(l, 1 - l); return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))); };
  return "#" + [f(0), f(8), f(4)].map((v) => v.toString(16).padStart(2, "0")).join("");
}
const GRASS = hsl("#6E8450");
function tint(svg, id) {
  const t = THEME[id], G = hsl(t.ground);
  return svg.replace(/#[0-9A-Fa-f]{6}/g, (c) => {
    if (c.toUpperCase() === "#1F2A1B") return t.bg;
    const [h, s, l] = hsl(c);
    if (id === "lava" && h >= 185 && h <= 215 && s > 0.2) return hex([22, 0.85, 0.45 + (l - 0.5) * 0.5]);      // 연못 → 용암 웅덩이
    if (h < 55 || h > 170 || s < 0.12) return c;      // 초록 계열만 테마 땅색으로
    return hex([G[0], Math.min(G[1], 0.5), Math.max(0.03, Math.min(0.97, G[2] + (l - GRASS[2]) * (id === "lava" ? 0.5 : 0.9)))]);
  });
}
boxes.v4_grass = mapPngs("v4", "grass", big, [1168, 700], 30 / 42, [59, 43.4], [265, 115]);
for (const id of ["snow", "sand", "lava"]) boxes["v4_" + id] = mapPngs("v4", id, tint(big, id), [1168, 700], 30 / 42, [59, 43.4], [265, 115]);
{
  const ghost = svgAt(map4, "0 0 566 360", 1);
  const d = ghost.match(/<path d="M(-?[\d.]+) ([\d.]+) L([\d.]+) ([\d.]+) L([\d.]+)/);
  const cell = +d[5] - +d[3];
  const ox = +d[3] - cell / 2, oy = +d[4] - cell / 2 - cell;
  console.log("ghost4 cell", cell, ox, oy);
  boxes.v4_ghost = mapPngs("v4", "ghost", ghost, [566, 360], 30 / cell, [ox, oy], [265, 115]);
}
fs.writeFileSync(path.join(TMP, "boxes.json"), JSON.stringify(boxes));

// ── 포탑 아틀라스 ──
const towers = read("Towers.dc.html").match(/<svg viewBox="-10 -64 120 168"[\s\S]*?<\/svg>/g);
{
  let body = "";
  towers.forEach((svg, n) => {
    const t = Math.floor(n / 4), mk = n % 4;
    const g = children(inner(svg)).filter((k) => k.startsWith("<g")).join("");
    for (let c = 0; c < 4; c++) {
      const x = (mk * 4 + c) * 120, y = t * 168;
      body += `<svg x="${x}" y="${y}" width="120" height="168" viewBox="-10 -64 120 168">${g.split("#E0533D").join(OWNER[c])}</svg>`;
    }
  });
  const png = shot("towers", `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1680">${body}</svg>`, 1920, 1680);
  fs.copyFileSync(png, path.join(ART, "towers.png"));
  console.log("towers", towers.length);
}

// ── 적 아틀라스 (일반병, 돌격병, 중장갑, 떼거리, 치유사, 보스 순서대로 시안에 있다) ──
const enemies = read("Enemies.dc.html").match(/<svg viewBox="0 0 180 170"[\s\S]*?<\/svg>/g);
{
  let body = "";
  enemies.forEach((svg, i) => {
    const g = children(inner(svg)).find((k) => k.startsWith("<g"));
    const m = g.match(/^<g transform="translate\(([-\d.]+) ([-\d.]+)\) scale\(([\d.]+)\)">/);
    const core = g.slice(g.indexOf(">") + 1, g.lastIndexOf("</g>"))      // 그림 속 체력 막대는 게임이 그린다
      .replace(/<rect [^>]*height="6" fill="#121518" stroke="#000000"[^>]*><\/rect>/g, "")
      .replace(/<rect [^>]*height="4" fill="#64D4A3"[^>]*><\/rect>/g, "");
    body += `<svg x="${i * 128}" y="0" width="128" height="128" viewBox="-14 -20 128 128">${core}</svg>`;
    console.log("enemy", i, m && m.slice(1).join(","));
  });
  const png = shot("enemies", `<svg xmlns="http://www.w3.org/2000/svg" width="${128 * enemies.length}" height="128">${body}</svg>`, 128 * enemies.length, 128);
  fs.copyFileSync(png, path.join(ART, "enemies.png"));
}

// ── 입구 기둥 ──
{
  const kit = read("Kit.dc.html");
  const gate = svgAt(kit, "0 0 220 220", 1);
  const kids = children(inner(gate)).filter((k) => !/^<rect x="0" y="0" width="220"/.test(k));
  const png = shot("gate", `<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220" viewBox="0 0 220 220">${kids.join("")}</svg>`, 220, 220);
  fs.copyFileSync(png, path.join(ART, "gate.png"));
}
console.log("BOXES", JSON.stringify(boxes));
