#!/usr/bin/env bash
# Build the two lab 10 PDFs: render diagrams, then print task1.html / task2.html with headless Chrome (or Edge).
set -euo pipefail
cd "$(dirname "$0")"
python diagrams/gen_overview.py
[ "${SKIP_PLANTUML:-0}" = 1 ] || bash diagrams/render.sh
PROFILE="$(mktemp -d)"
for pair in "task1:BTH10-Task1-Kien-truc-tong-quat-2424802010029" "task2:BTH10-Task2-Kien-truc-4-khung-nhin-2424802010029"; do
  src="${pair%%:*}"; dst="${pair#*:}"; tmp="$PWD/_build.pdf"; ok=0
  for browser in "${BROWSER_EXE:-}" "/c/Program Files/Google/Chrome/Application/chrome.exe" "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    [ -n "$browser" ] && [ -x "$browser" ] || continue
    "$browser" --headless=new --disable-gpu --no-pdf-header-footer --user-data-dir="$(cygpath -w "$PROFILE")" \
      --print-to-pdf="$(cygpath -w "$tmp")" "file:///$(cygpath -m "$PWD")/$src.html" >/dev/null 2>&1 || true
    if [ -s "$tmp" ]; then mv -f "$tmp" "$dst.pdf"; ok=1; break; fi
  done
  [ "$ok" = 1 ] || { echo "PDF export failed: $src.html" >&2; exit 1; }
  echo "built $dst.pdf"
done
