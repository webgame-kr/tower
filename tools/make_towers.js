// 시안에 없는 새 포탑 4종(전기·저격·신호·가시 덫개)을 기존 포탑 판과 같은 그림체로 그려 아틀라스 아래에 붙인다.
// 칸: 128px, 열 = 강화 단계(MK-1, MK-2, MK-3a, MK-3b) x 주인 색 4, 행 6~9 = 새 포탑
// 사용: node tools/make_towers.js <원본 towers.png> <임시 폴더> <출력 png>
const fs = require("fs"), path = require("path"), { spawnSync } = require("child_process");
const [, , SRC, TMP, OUT] = process.argv;
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const INK = "#121518", PLATE = "#555B61", STEEL = "#8C939A", DARK = "#3A4046", AMBER = "#C9961E";
const OWNER = ["#E0533D", "#3D6FD1", "#E9B935", "#38A672"];
const src = "data:image/png;base64," + fs.readFileSync(SRC).toString("base64");

// 판 가운데를 비우는 덮개 (기관포 판 기준)
const blank = `<rect x="27" y="31" width="74" height="74" rx="4" fill="${PLATE}"/>`;

function shock(mk) {
  let s = `<ellipse cx="64" cy="92" rx="26" ry="9" fill="${DARK}" stroke="${INK}" stroke-width="3"/>`;
  const rings = mk === 0 ? 3 : 4;
  for (let i = 0; i < rings; i++) {
    const y = 86 - i * 11;
    s += `<ellipse cx="64" cy="${y}" rx="${19 - i * 2}" ry="6" fill="#B87A2E" stroke="${INK}" stroke-width="2.5"/>`;
    s += `<ellipse cx="64" cy="${y - 2}" rx="${15 - i * 2}" ry="3" fill="#E0A85A"/>`;
  }
  const top = 86 - rings * 11;
  const balls = mk === 2 ? [[50, top], [78, top]] : [[64, top - 2]];
  for (const [x, y] of balls) {
    s += `<circle cx="${x}" cy="${y}" r="${mk === 1 ? 13 : 11}" fill="#9FD8E6" stroke="${INK}" stroke-width="3"/>`;
    s += `<circle cx="${x - 3}" cy="${y - 3}" r="4" fill="#E6F7FC"/>`;
  }
  if (mk === 3) {
    for (let k = 0; k < 6; k++) {
      const a = (Math.PI * 2 * k) / 6;
      s += `<line x1="${64 + Math.cos(a) * 12}" y1="${top - 2 + Math.sin(a) * 12}" x2="${64 + Math.cos(a) * 19}" y2="${top - 2 + Math.sin(a) * 19}" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>`;
    }
  }
  s += `<path d="M66 ${top - 12} L58 ${top} L65 ${top} L61 ${top + 9} L71 ${top - 4} L64 ${top - 4} Z" fill="#F4D35E" stroke="${INK}" stroke-width="1.5"/>`;
  return s;
}

function sniper(mk) {
  const len = mk === 0 ? 46 : 54;
  const bw = mk === 2 ? 12 : 8;
  let s = `<rect x="44" y="62" width="40" height="34" rx="4" fill="${DARK}" stroke="${INK}" stroke-width="3"/>`;
  s += `<rect x="${64 - bw / 2}" y="${66 - len}" width="${bw}" height="${len}" fill="${STEEL}" stroke="${INK}" stroke-width="3"/>`;
  s += `<rect x="${64 - bw / 2 - 3}" y="${62 - len}" width="${bw + 6}" height="9" fill="${DARK}" stroke="${INK}" stroke-width="2.5"/>`;
  if (mk >= 1) s += `<rect x="${64 - bw / 2 - 2}" y="${74 - len}" width="${bw + 4}" height="5" fill="${INK}"/>`;
  const scopes = mk === 3 ? [72, 86] : [74];
  for (const x of scopes) {
    s += `<rect x="${x}" y="52" width="9" height="24" rx="3" fill="${DARK}" stroke="${INK}" stroke-width="2.5"/>`;
    s += `<circle cx="${x + 4.5}" cy="54" r="3.5" fill="#8FB0F0" stroke="${INK}" stroke-width="1.5"/>`;
  }
  s += `<rect x="50" y="78" width="28" height="8" rx="2" fill="${AMBER}" stroke="${INK}" stroke-width="2"/>`;
  return s;
}

function signal(mk) {
  let s = `<rect x="58" y="${mk === 2 ? 34 : 44}" width="12" height="${mk === 2 ? 60 : 50}" fill="${STEEL}" stroke="${INK}" stroke-width="3"/>`;
  s += `<rect x="46" y="86" width="36" height="12" rx="3" fill="${DARK}" stroke="${INK}" stroke-width="3"/>`;
  const dy = mk === 2 ? 0 : 8;
  s += `<path d="M40 ${48 + dy} Q64 ${78 + dy} 88 ${48 + dy} Z" fill="#D3D9DC" stroke="${INK}" stroke-width="3"/>`;
  s += `<line x1="64" y1="${58 + dy}" x2="64" y2="${36 + dy}" stroke="${INK}" stroke-width="3"/>`;
  s += `<circle cx="64" cy="${34 + dy}" r="5" fill="#FF4A3A" stroke="${INK}" stroke-width="2"/>`;
  const arcs = mk === 0 ? 1 : 2;
  for (let i = 0; i < arcs; i++) {
    const r = 12 + i * 8;
    s += `<path d="M${64 - r} ${34 + dy - r * 0.2} A${r} ${r} 0 0 1 ${64 + r} ${34 + dy - r * 0.2}" fill="none" stroke="#F4BB60" stroke-width="3" stroke-linecap="round"/>`;
  }
  if (mk === 3) {
    s += `<circle cx="64" cy="${66}" r="9" fill="none" stroke="#FF4A3A" stroke-width="2.5"/><line x1="52" y1="66" x2="76" y2="66" stroke="#FF4A3A" stroke-width="2"/><line x1="64" y1="54" x2="64" y2="78" stroke="#FF4A3A" stroke-width="2"/>`;
  }
  return s;
}

// 함정은 판 없이 길 위에 깔리는 철판
function spike(mk, owner) {
  let s = `<rect x="14" y="18" width="100" height="96" rx="8" fill="#4A4F55" stroke="${INK}" stroke-width="4"/>`;
  s += `<rect x="22" y="26" width="84" height="80" rx="4" fill="${mk === 2 ? "#6E7A3A" : "#3A4046"}"/>`;
  s += `<path d="M14 104 L114 104" stroke="#E9B935" stroke-width="6" stroke-dasharray="8 8"/>`;
  const n = mk === 0 ? 3 : 4;
  const big = mk === 3;
  const step = 84 / n;
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
    const cx = 22 + step * (i + 0.5), cy = 26 + step * (j + 0.5) + 2;
    const h = big ? step * 0.48 : step * 0.36;
    if (mk === 2) s += `<circle cx="${cx}" cy="${cy}" r="${step * 0.26}" fill="#C8D46A" stroke="${INK}" stroke-width="1.5" opacity="0.9"/>`;
    else s += `<path d="M${cx - h} ${cy + h * 0.7} L${cx} ${cy - h} L${cx + h} ${cy + h * 0.7} Z" fill="#C9CED3" stroke="${INK}" stroke-width="2"/>`;
  }
  s += `<rect x="94" y="8" width="24" height="24" rx="3" fill="${OWNER[owner]}" stroke="${INK}" stroke-width="2.5"/><circle cx="106" cy="20" r="6" fill="none" stroke="#fff" stroke-width="2.5"/>`;
  return s;
}

const makers = [shock, sniper, signal, spike];
let body = `<image href="${src}" x="0" y="0" width="2048" height="768"/>`;
makers.forEach((fn, ri) => {
  for (let mk = 0; mk < 4; mk++) for (let col = 0; col < 4; col++) {
    const x = (mk * 4 + col) * 128, y = (6 + ri) * 128;
    if (fn === spike) {
      body += `<g transform="translate(${x} ${y})">${spike(mk, col)}</g>`;
    } else {
      // 같은 주인 색의 기관포 판을 깔고 가운데를 비운 뒤 새 머리를 얹는다
      body += `<svg x="${x}" y="${y}" width="128" height="128" viewBox="${col * 128} 0 128 128"><image href="${src}" x="0" y="0" width="2048" height="768"/></svg>`;
      body += `<g transform="translate(${x} ${y})">${blank}${fn(mk)}</g>`;
    }
  }
});
fs.mkdirSync(TMP, { recursive: true });
const html = path.join(TMP, "towers.html");
fs.writeFileSync(html, `<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent}</style><svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1280" viewBox="0 0 2048 1280">${body}</svg>`);
try { fs.unlinkSync(OUT); } catch (e) {}
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars", "--force-device-scale-factor=1", "--default-background-color=00000000",
  "--user-data-dir=" + path.join(TMP, "prof"), "--window-size=2048,1280", "--screenshot=" + OUT, "file:///" + html.split(path.sep).join("/")], { stdio: "ignore", timeout: 60000 });
console.log(fs.existsSync(OUT) ? "ok " + fs.statSync(OUT).size : "FAILED");
