#!/usr/bin/env bash
# Drop Nityanand's research-docs scaffold into the current (or given) repo.
#
#   curl -fsSL https://nityanandmathur.com/docs.sh | bash
#   curl -fsSL https://nityanandmathur.com/docs.sh | bash -s -- --title "My Paper" --tagline "One line."
#   bash <(curl -fsSL https://nityanandmathur.com/docs.sh) --dir /path/to/repo --force
#
# Source of truth: https://nityanandmathur.com/docs/ (live preview) + docs.tgz
set -euo pipefail

DOCS_URL="${DOCS_URL:-https://nityanandmathur.com/docs.tgz}"
DOCS_TGZ="${DOCS_TGZ:-}"   # optional local .tgz override (skip download)
DIR="."
TITLE=""
TAGLINE="A research write-up."
REPO_URL=""
FORCE=0
DATE="$(date +%Y-%m-%d)"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERR\033[0m  %s\n' "$*" >&2; exit 1; }

fetch_kit() {
  local dest="$1"
  if [ -n "$DOCS_TGZ" ]; then
    [ -f "$DOCS_TGZ" ] || die "DOCS_TGZ not found: $DOCS_TGZ"
    log "Using local kit: $DOCS_TGZ"
    tar -xzf "$DOCS_TGZ" -C "$dest"
  else
    log "Downloading docs kit from $DOCS_URL"
    curl -fsSL "$DOCS_URL" | tar -xz -C "$dest"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="$2"; shift 2 ;;
    --title)   TITLE="$2"; shift 2 ;;
    --tagline) TAGLINE="$2"; shift 2 ;;
    --repo)    REPO_URL="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

DIR="$(cd "$DIR" && pwd)"
DOCS="$DIR/docs"
[ -n "$TITLE" ] || TITLE="$(basename "$DIR")"

normalize_repo() {
  local url="$1"; url="${url%.git}"
  case "$url" in
    git@*) local rest="${url#git@}"; printf 'https://%s/%s' "${rest%%:*}" "${rest#*:}" ;;
    ssh://git@*) printf 'https://%s' "${url#ssh://git@}" ;;
    *) printf '%s' "$url" ;;
  esac
}
if [ -z "$REPO_URL" ]; then
  origin="$(git -C "$DIR" remote get-url origin 2>/dev/null || true)"
  [ -n "$origin" ] && REPO_URL="$(normalize_repo "$origin")" || REPO_URL="#"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ -d "$DOCS" ] && [ "$FORCE" != 1 ]; then
  # Refresh design system only; keep authored pages
  log "docs/ exists — refreshing theme + serve.py (use --force to overwrite pages)"
  fetch_kit "$tmp"
  mkdir -p "$DOCS/assets" "$DOCS/figures" "$DOCS/audio"
  cp "$tmp/docs/assets/theme.css" "$DOCS/assets/theme.css"
  cp "$tmp/docs/assets/theme.js"  "$DOCS/assets/theme.js"
  cp "$tmp/docs/serve.py"         "$DOCS/serve.py"
  log "synced $DOCS/assets/theme.css, theme.js, serve.py"
  echo "  preview: python3 \"$DOCS/serve.py\""
  exit 0
fi

if [ -d "$DOCS" ] && [ "$FORCE" = 1 ]; then
  warn "removing existing $DOCS (--force)"
  rm -rf "$DOCS"
fi

fetch_kit "$tmp"
mv "$tmp/docs" "$DOCS"

# Substitute placeholders in pages
render_file() {
  local f="$1"
  local content; content="$(cat "$f")"
  content="${content//\{\{TITLE\}\}/$TITLE}"
  content="${content//\{\{TAGLINE\}\}/$TAGLINE}"
  content="${content//\{\{DATE\}\}/$DATE}"
  content="${content//\{\{REPO_URL\}\}/$REPO_URL}"
  printf '%s\n' "$content" > "$f"
}
render_file "$DOCS/index.html"
render_file "$DOCS/report.html"

log "docs/ ready at: $DOCS"
echo "  title:   $TITLE"
echo "  tagline: $TAGLINE"
echo "  preview: python3 \"$DOCS/serve.py\"   # http://127.0.0.1:8000"
echo "  live kit preview: https://nityanandmathur.com/docs/"
