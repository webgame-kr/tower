#!/usr/bin/env bash
# 테스트 후 웹 빌드를 docs/ 로 내보낸다.
set -e
cd "$(dirname "$0")/.."
. ./.godotbin
"$G" --headless --path . --import >/dev/null 2>&1 || true
for t in run_tests net_tests; do
  out=$("$G" --headless --path . -s "res://tests/$t.gd" 2>&1) || { echo "$out"; exit 1; }
  echo "$out" | grep -E 'passed'
  if echo "$out" | grep -q "SCRIPT ERROR"; then echo "$out"; exit 1; fi
done
smoke=$(timeout 25 "$G" --headless --path . --quit-after 30 2>&1 || true)
if echo "$smoke" | grep -qE 'SCRIPT ERROR|Parse Error'; then echo "$smoke" | grep -E -A1 'SCRIPT ERROR|Parse Error'; exit 1; fi
"$G" --headless --path . --export-release "Web" docs/index.html 2>&1 | grep -E 'ERROR|error' || true
cp web/gil_net.js web/gil_ui.js docs/
touch docs/.gdignore
printf '<!doctype html><meta charset="utf-8"><title>길 좀 막아봐</title><script>location.replace("docs/"+location.search)</script>\n' > index.html
ls -la docs | head -20
