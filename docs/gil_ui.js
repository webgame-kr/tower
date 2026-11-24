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
    el.style.cssText = "position:fixed;z-index:20;box-sizing:border-box;height:34px;padding:0 10px;border-radius:7px;" +
      "border:1px solid #5d6f58;background:#17201aee;color:#f4f1e4;font:14px 'Malgun Gothic','Apple SD Gothic Neo',sans-serif;outline:none;display:none";
    el.addEventListener("focus", function () { el.style.borderColor = "#f0c75e"; });
    el.addEventListener("blur", function () { el.style.borderColor = "#5d6f58"; });
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
      el.style.display = "block";
    },
    hide: function (id) { if (fields[id]) { fields[id].style.display = "none"; fields[id].blur(); } },
    focus: function (id) { if (fields[id]) fields[id].focus(); },
    value: function (id) { return fields[id] ? fields[id].value : ""; },
    put: function (id, v) { var el = fields[id]; if (el && document.activeElement !== el) el.value = v; },
    take: function (id) { var a = sent[id] || []; sent[id] = []; return JSON.stringify(a); },
    typing: function () { var a = document.activeElement; return !!a && a.tagName === "INPUT"; },
    saved: function () { try { return localStorage.getItem("gil_name") || ""; } catch (e) { return ""; } },
    save: function (v) { try { localStorage.setItem("gil_name", v); } catch (e) {} }
  };
})();
