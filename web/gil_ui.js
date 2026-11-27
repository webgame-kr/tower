// 글자 입력은 브라우저 입력창으로 받는다: 한글 조합, 단축키 차단, 맵 클릭 차단을 브라우저가 정확히 처리한다.
(function () {
  var fields = {};
  var sent = {};

  function make(id, placeholder, maxLen) {
    var el = document.createElement("input");
    el.type = "text";
    el.maxLength = maxLen;
    el.placeholder = placeholder;
    el.autocomplete = "off";
    el.spellcheck = false;
    el.style.cssText = "position:fixed;z-index:20;box-sizing:border-box;height:34px;padding:0 12px;border-radius:4px;" +
      "border:1px solid #405068;background:#1c1e22;color:#eff5ff;font:14px 'Malgun Gothic','Apple SD Gothic Neo',sans-serif;outline:none;display:none";
    el.addEventListener("focus", function () { el.style.borderColor = "#f4bb60"; });
    el.addEventListener("blur", function () { el.style.borderColor = "#405068"; });
    el.addEventListener("keydown", function (e) {
      e.stopPropagation();
      // 한글 조합을 확정하는 Enter 는 전송이 아니다
      if (e.isComposing || e.keyCode === 229) return;
      if (e.key === "Enter") {
        e.preventDefault();
        var v = el.value.trim();
        if (v) { (sent[id] = sent[id] || []).push(v); if (el.dataset.keep !== "1") el.value = ""; }
        else el.blur();
      } else if (e.key === "Escape") {
        e.preventDefault();
        if (el.dataset.keep !== "1") el.value = "";
        el.blur();
        var c = document.querySelector("canvas");
        if (c) c.focus();
      }
    });
    el.addEventListener("keyup", function (e) { e.stopPropagation(); });
    el.addEventListener("keypress", function (e) { e.stopPropagation(); });
    ["mousedown", "mouseup", "click", "pointerdown", "pointerup", "touchstart", "touchend", "wheel"].forEach(function (n) {
      el.addEventListener(n, function (e) { e.stopPropagation(); });
    });
    document.body.appendChild(el);
    fields[id] = el;
    return el;
  }

  window.GilUI = {
    // x, y, w 는 캔버스 CSS 픽셀 비율(0~1)이 아니라 게임 화면 좌표. scale 로 변환한다.
    show: function (id, placeholder, maxLen, x, y, w, scale, keep) {
      var el = fields[id] || make(id, placeholder, maxLen);
      var c = document.querySelector("canvas");
      var r = c ? c.getBoundingClientRect() : { left: 0, top: 0 };
      el.dataset.keep = keep ? "1" : "0";
      el.style.left = (r.left + x * scale) + "px";
      el.style.top = (r.top + y * scale) + "px";
      el.style.width = (w * scale) + "px";
      el.style.height = (38 * scale) + "px";
      el.style.fontSize = Math.max(9, 14 * scale) + "px";
      el.style.display = "block";
    },
    hide: function (id) { if (fields[id]) { fields[id].style.display = "none"; fields[id].blur(); } },
    focus: function (id) { if (fields[id]) fields[id].focus(); },
    value: function (id) { return fields[id] ? fields[id].value : ""; },
    put: function (id, v) { var el = fields[id]; if (el && document.activeElement !== el) el.value = v; },
    take: function (id) { var a = sent[id] || []; sent[id] = []; return JSON.stringify(a); },
    typing: function () { var a = document.activeElement; return !!a && a.tagName === "INPUT"; },
    saved: function () { try { return localStorage.getItem("gil_name") || ""; } catch (e) { return ""; } },
    load_key: function (k) { try { return localStorage.getItem("gil_" + k) || ""; } catch (e) { return ""; } },
    save_key: function (k, v) { try { localStorage.setItem("gil_" + k, v); } catch (e) {} },
    save: function (v) { try { localStorage.setItem("gil_name", v); } catch (e) {} }
  };
})();

// 태블릿·휴대폰: 브라우저 제스처 막기, 세로 화면 안내, 첫 터치에 전체 화면 + 가로 고정
(function () {
  var ua = navigator.userAgent || "";
  var coarse = (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) ||
    /Android|iPhone|iPad|Mobile/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var st = document.createElement("style");
  st.textContent = "html,body{overscroll-behavior:none;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}" +
    "canvas{touch-action:none;-webkit-tap-highlight-color:transparent;-webkit-touch-callout:none}" +
    "#gil-rotate{position:fixed;inset:0;z-index:30;display:none;flex-direction:column;align-items:center;justify-content:center;gap:14px;" +
    "background:#16191c;color:#e8e4da;font:600 18px/1.5 sans-serif;text-align:center;padding:24px}" +
    "#gil-rotate b{font-size:44px;display:block;transform:rotate(90deg)}";
  document.head.appendChild(st);
  if (!coarse) return;
  var rot = document.createElement("div");
  rot.id = "gil-rotate";
  rot.innerHTML = "<b>↻</b>기기를 가로로 돌려 주세요<span style='font-size:14px;opacity:.7'>길 좀 막아봐는 가로 화면에서 해요</span>";
  function check() { rot.style.display = window.innerHeight > window.innerWidth * 1.05 ? "flex" : "none"; }
  function ready() { document.body.appendChild(rot); check(); }
  if (document.body) ready(); else document.addEventListener("DOMContentLoaded", ready);
  window.addEventListener("resize", check);
  window.addEventListener("orientationchange", function () { setTimeout(check, 200); });
  var tried = false;
  document.addEventListener("touchend", function (e) {
    if (tried || (e.target && e.target.tagName === "INPUT")) return;
    tried = true;
    var el = document.documentElement;
    var req = el.requestFullscreen || el.webkitRequestFullscreen;
    if (!req || document.fullscreenElement || document.webkitFullscreenElement) return;
    try {
      var pr = req.call(el, { navigationUI: "hide" });
      if (pr && pr.then) pr.then(function () {
        if (screen.orientation && screen.orientation.lock) screen.orientation.lock("landscape").catch(function () {});
      }).catch(function () {});
    } catch (err) {}
  }, { passive: true });
  document.addEventListener("dblclick", function (e) { e.preventDefault(); }, { passive: false });
})();
