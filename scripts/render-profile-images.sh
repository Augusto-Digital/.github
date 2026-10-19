#!/usr/bin/env bash
# Render the brand images used by profile/README.md (hero banner, buttons,
# domain marks) from scripts/profile-images/images.html.
#
# A README cannot load fonts or set colours, so the 2026 brand's type and
# palette reach the profile as PNGs. Each image is rendered at 2x (domain
# marks at 4x) on a transparent ground, light and dark variants where GitHub's
# dark theme would hide the light one.
#
#   ./scripts/render-profile-images.sh
#
# Requires: a headless Chrome. Defaults to Playwright's chrome-headless-shell
# (npx playwright install chromium-headless-shell); set CHROME to override.
# Needs network access for the Google Fonts request.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$here/profile"
page="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$here/scripts/profile-images/images.html")"

if [[ -z "${CHROME:-}" ]]; then
  CHROME="$(ls -d "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell \
                  "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell 2>/dev/null | tail -1 || true)"
fi
[[ -x "${CHROME:-}" ]] || { echo "error: no headless Chrome found; set CHROME" >&2; exit 1; }

flags=(--headless --disable-gpu --hide-scrollbars --virtual-time-budget=15000)

# render NAME SCALE QUERY: measure the element, then screenshot exactly it.
render() {
  local name="$1" scale="$2" query="$3" size
  size="$("$CHROME" "${flags[@]}" --dump-dom "$page?$query" 2>/dev/null \
          | sed -n 's/.*<pre id="size">\([0-9]*\) \([0-9]*\)<\/pre>.*/\1,\2/p')"
  [[ -n "$size" ]] || { echo "error: could not measure $name" >&2; exit 1; }
  "$CHROME" "${flags[@]}" --force-device-scale-factor="$scale" --default-background-color=00000000 \
    --window-size="$size" --screenshot="$out/$name.png" "$page?$query" >/dev/null 2>&1
  echo "$name.png  ${size/,/x} @${scale}x"
}

for mode in light dark; do
  render "banner-$mode" 2 "img=banner&mode=$mode"
  for name in finance revenue marketing hr operations company it security engineering; do
    render "icon-$name-$mode" 4 "img=icon&name=$name&mode=$mode"
  done
done
# Buttons get one file each, no dark variant: GitHub splits a <picture> that
# sits inside a link, so a linked image has to read on both themes. Ember
# with an Ink label does; the secondaries are Ink with a Bone label.
render "btn-assessment" 2 "img=btn&kind=fill&size=hero&label=assessment"
render "btn-rumble" 2 "img=btn&kind=fill&label=rumble"
for label in cases roles website; do
  render "btn-$label" 2 "img=btn&kind=solid&label=$label"
done
