// 디자인 시안(Themes)의 테마별 지형을 두 장의 이미지로 뽑는다.
//   <id>_base.png : 외곽 배경 + 지면 + 절벽 (길 아래)
//   <id>_over.png : 작업장 + 랜드마크 + 본부 + 입구 (길 위)
// 길, 실제 효과 구역, 격자는 게임이 판정 데이터로 직접 그리므로 뺀다.
// 사용: node tools/extract_map.js <시안 project 폴더> <임시 폴더> <출력 폴더>
const fs = require("fs"), path = require("path"), { spawn } = require("child_process");
const [, , P, TMP, OUT] = process.argv;
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const THEMES = [["grass", 0, null], ["snow", 1, [49, 78]], ["sand", 3, [44, 44, 49, 49]], ["lava", 5, [69, 87]], ["ghost", 7, [370, 372]]];
// 시안 좌표: 칸 15, 플레이 영역 시작 (75.5, 43). 게임 화면: 칸 24, 틀 안 여백 (81, 54)
const VIEW = `${75.5 - 81 / 1.6} ${43 - 54 / 1.6} ${810 / 1.6} ${540 / 1.6}`;
const W = 1215, H = 810;

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
const attr = (k, n) => (k.slice(0, k.indexOf(">")).match(new RegExp(" " + n + '="([^"]+)"')) || [])[1] || "";
const page = (body) => `<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent;width:${W}px;height:${H}px;overflow:hidden}</style><svg xmlns="http://www.w3.org/2000/svg" viewBox="${VIEW}" width="${W}" height="${H}">${body}</svg>`;

function shot(html, png, n) {
  return new Promise((done) => {
    const prof = path.join(TMP, "prof-" + n);
    fs.mkdirSync(prof, { recursive: true });
    try { fs.unlinkSync(png); } catch (e) {}
    const p = spawn(EDGE, ["--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars", "--force-device-scale-factor=1",
      "--default-background-color=00000000", "--user-data-dir=" + prof, `--window-size=${W},${H}`, "--screenshot=" + png, "file:///" + html.replace(/\\/g, "/")], { stdio: "ignore" });
    const t0 = Date.now();
    const iv = setInterval(() => {
      if ((fs.existsSync(png) && fs.statSync(png).size > 0) || Date.now() - t0 > 40000) {
        clearInterval(iv);
        setTimeout(() => { try { p.kill(); } catch (e) {} done(fs.existsSync(png)); }, 500);
      }
    }, 300);
  });
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const a = fs.readFileSync(path.join(P, "Themes.dc.html"), "utf8").match(/<svg[\s\S]*?<\/svg>/g);
  const road = {};
  for (const [id, idx, skip] of THEMES) {
    const g = children(inner(a[idx])).find((t) => t.startsWith("<g clip"));
    const kids = children(g.slice(g.indexOf(">") + 1, g.lastIndexOf("</g>")));
    const grid = kids.findIndex((k) => k.startsWith("<path") && attr(k, "stroke-width") === "1" && k.length === 967);
    let arrow = grid + 1;
    while (!kids[arrow].startsWith("<g")) arrow++;
    road[id] = kids.slice(grid + 1, arrow).map((k) => [attr(k, "stroke"), +(parseFloat(attr(k, "stroke-width")) / 15).toFixed(3), attr(k, "stroke-dasharray") ? 1 : 0, +(attr(k, "opacity") || attr(k, "stroke-opacity") || 1)]);
    let second = arrow + 1;
    while (!kids[second].startsWith("<g")) second++;
    const hidden = (i) => { if (!skip) return false; for (let s = 0; s < skip.length; s += 2) if (i >= skip[s] && i <= skip[s + 1]) return true; return false; };
    const over = kids.filter((k, i) => i > second && !hidden(i));
    if (id === "sand") console.log("sand zone", attr(kids[44], "cx"), attr(kids[44], "cy"), attr(kids[44], "r"));
    for (const [suffix, body] of [["base", kids.slice(0, grid).join("")], ["over", over.join("")]]) {
      const html = path.join(TMP, `${id}_${suffix}.html`);
      fs.writeFileSync(html, page(body));
      const ok = await shot(html, path.join(OUT, `${id}_${suffix}.png`), id + suffix);
      console.log(id, suffix, ok ? fs.statSync(path.join(OUT, `${id}_${suffix}.png`)).size : "FAILED");
    }
  }
  console.log("ROADS " + JSON.stringify(road));
  process.exit(0);
})();
