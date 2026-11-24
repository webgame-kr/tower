// 디자인 시안(.dc.html)의 SVG 원본을 게임 스프라이트 시트용 HTML 로 묶는다.
// 사용: node tools/extract_art.js <시안 project 폴더> <출력 폴더>
const fs = require("fs"), path = require("path");
const [, , P, O] = process.argv;
const svgs = (n) => fs.readFileSync(path.join(P, n + ".dc.html"), "utf8").match(/<svg[\s\S]*?<\/svg>/g);
const inner = (s) => s.slice(s.indexOf(">") + 1, s.lastIndexOf("</svg>"));
const vb = (s) => s.match(/viewBox="([^"]+)"/)[1];
const put = (s, x, y, size, box) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${box || vb(s)}" width="${size}" height="${size}" style="position:absolute;left:${x}px;top:${y}px">${inner(s)}</svg>`;
const page = (name, w, h, body) => fs.writeFileSync(path.join(O, name + ".html"),
  `<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent;width:${w}px;height:${h}px;overflow:hidden}</style>${body}`);

const T = svgs("Towers");
const TAG = /<g transform="translate\(86 14\)[\s\S]*?<\/g><\/g>/;
const owners = [30, 31, 32, 33].map((i) => {
  const tag = T[i].match(TAG)[0];
  return { tag, col: tag.match(/fill="(#[0-9A-Fa-f]{6})"/)[1] };
});
const recolor = (s, o) => s.replace(TAG, o.tag)
  .replace(/(<rect x="8" y="44" width="4" height="12" fill=")#[0-9A-Fa-f]{6}/g, `$1${o.col}`)
  .replace(/(<rect x="88" y="44" width="4" height="12" fill=")#[0-9A-Fa-f]{6}/g, `$1${o.col}`);
let b = "";
for (let ty = 0; ty < 6; ty++) for (let mk = 0; mk < 4; mk++) for (let o = 0; o < 4; o++)
  b += put(recolor(T[1 + ty * 5 + mk], owners[o]), (mk * 4 + o) * 128, ty * 128, 128);
page("towers", 2048, 768, b);

const E = svgs("Enemies");
b = "";
for (let i = 0; i < 6; i++) b += put(E[i], i * 128, 0, 128);
page("enemies", 768, 128, b);

const C = svgs("Comms"), R = svgs("Prep");
b = "";
for (let i = 0; i < 7; i++) b += put(E[11 + i], i * 64, 0, 64);               // 상태 아이콘
[26, 27, 28, 29, 30].forEach((k, i) => (b += put(R[k], i * 64, 64, 64)));     // 핑 버튼
[2, 3, 4, 8, 9, 10, 18, 25].forEach((k, i) => (b += put(R[k], i * 64, 128, 64))); // HUD
for (let i = 0; i < 5; i++) b += put(C[i], i * 128, 192, 128, "0 0 122 122"); // 지도 핀
page("icons", 640, 320, b);

const map = R[1];
page("castle", 360, 360, put(map, 0, 0, 360, "360 211 90 90"));
page("gate", 240, 120, put(map, 0, 0, 120, "0 241 30 30") + put(map, 120, 0, 120, "780 241 30 30"));
console.log("owners", owners.map((o) => o.col).join(" "));
