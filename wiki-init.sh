#!/usr/bin/env bash
# wiki-init — standalone project wiki bootstrap
# Works with any agentic coding tool that reads AGENTS.md or CLAUDE.md.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lenminh002/project-wiki/main/wiki-init.sh | bash
#   # or from a clone: ./wiki-init.sh
set -e

REPO="https://raw.githubusercontent.com/lenminh002/project-wiki/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
PROJECT_DIR="$(pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

prompt() {
  # prompt <var_name> <message> [default]
  local var="$1" msg="$2" default="${3:-}"
  if [ -n "$default" ]; then
    printf "%s [%s]: " "$msg" "$default" >&2
  else
    printf "%s: " "$msg" >&2
  fi
  local input
  read -r input </dev/tty
  if [ -z "$input" ] && [ -n "$default" ]; then
    input="$default"
  fi
  eval "$var=\$input"
}

yn() {
  # yn <message> [default y|n] → returns 0 for yes, 1 for no
  local msg="$1" default="${2:-n}"
  local hint
  if [ "$default" = "y" ]; then hint="Y/n"; else hint="y/N"; fi
  printf "%s [%s]: " "$msg" "$hint" >&2
  local input
  read -r input </dev/tty
  input="${input:-$default}"
  case "$input" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

fetch_template() {
  local name="$1" dest="$2"
  local local_src="$SCRIPT_DIR/templates/$name"
  if [ -f "$local_src" ]; then
    cp "$local_src" "$dest"
  else
    curl -fsSL "$REPO/templates/$name" -o "$dest"
  fi
}

render_context() {
  # Substitute {{placeholders}} in the template file in-place
  local file="$1"
  local name="$2" goal="$3" stack="$4" deployed="$5" tree="$6" conventions="$7"
  # Use a temp file; avoid pipeline so newlines in values are safe
  local tmp
  tmp="$(mktemp)"
  sed \
    -e "s|{{name}}|$name|g" \
    -e "s|{{goal}}|$goal|g" \
    -e "s|{{stack}}|$stack|g" \
    -e "s|{{deployed_on}}|$deployed|g" \
    "$file" > "$tmp"
  # folder_structure and conventions may be multi-line; use Python/awk if available
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$tmp" "$tree" "$conventions" <<'PYEOF'
import sys, pathlib
f, tree, conventions = sys.argv[1], sys.argv[2], sys.argv[3]
content = pathlib.Path(f).read_text()
content = content.replace("{{folder_structure}}", tree)
content = content.replace("{{conventions}}", conventions)
pathlib.Path(f).write_text(content)
PYEOF
  else
    # Fallback: single-line values only
    sed -i.bak "s|{{folder_structure}}|$tree|g" "$tmp" 2>/dev/null || sed -i "" "s|{{folder_structure}}|$tree|g" "$tmp"
    sed -i.bak "s|{{conventions}}|$conventions|g" "$tmp" 2>/dev/null || sed -i "" "s|{{conventions}}|$conventions|g" "$tmp"
    rm -f "$tmp.bak"
  fi
  mv "$tmp" "$file"
}

write_rules() {
  local target="$1" snippet="$2"
  if [ -f "$target" ] && grep -q "# Wiki workflow" "$target" 2>/dev/null; then
    echo "  $target already contains wiki rules — skipping (idempotent)"
    return
  fi
  if [ -f "$target" ]; then
    # Ensure trailing newline before appending
    [ "$(tail -c1 "$target" | wc -l)" -eq 0 ] && printf "\n" >> "$target"
    printf "\n" >> "$target"
    cat "$snippet" >> "$target"
    echo "  Appended wiki rules to $target"
  else
    cp "$snippet" "$target"
    echo "  Created $target with wiki rules"
  fi
}

# ── Step 1: check for existing wiki ──────────────────────────────────────────

OVERWRITE=false
if [ -d "$PROJECT_DIR/wiki" ]; then
  echo "A wiki/ folder already exists in this project."
  printf "What would you like to do? [skip / overwrite / cancel] (default: skip): " >&2
  read -r choice </dev/tty
  choice="${choice:-skip}"
  case "$choice" in
    overwrite) OVERWRITE=true ;;
    cancel)    echo "Cancelled."; exit 0 ;;
    *)         echo "Leaving existing wiki/ untouched."; OVERWRITE=false ;;
  esac
fi

# ── Step 2: scaffold folder tree ─────────────────────────────────────────────

echo ""
echo "Scaffolding wiki/ folder..."

mkdir -p \
  "$PROJECT_DIR/wiki/bugs/open" \
  "$PROJECT_DIR/wiki/bugs/fixed" \
  "$PROJECT_DIR/wiki/plans/active" \
  "$PROJECT_DIR/wiki/plans/done" \
  "$PROJECT_DIR/wiki/plans/abandoned"

for dir in \
  "$PROJECT_DIR/wiki/bugs/open" \
  "$PROJECT_DIR/wiki/bugs/fixed" \
  "$PROJECT_DIR/wiki/plans/active" \
  "$PROJECT_DIR/wiki/plans/done" \
  "$PROJECT_DIR/wiki/plans/abandoned"; do
  touch "$dir/.gitkeep"
done

echo "  Created wiki/ directory tree"

# ── Step 3: fetch templates to a temp dir ────────────────────────────────────

TPL_DIR="$(mktemp -d)"
trap 'rm -rf "$TPL_DIR"' EXIT

fetch_template "CONTEXT.md"       "$TPL_DIR/CONTEXT.md"
fetch_template "log.md"           "$TPL_DIR/log.md"
fetch_template "rules.md.snippet" "$TPL_DIR/rules.md.snippet"

# ── Step 4: inspect the project ──────────────────────────────────────────────

TREE="$(ls -1 "$PROJECT_DIR" 2>/dev/null | grep -v '^wiki$' | head -30 | sed 's/^/  /')"

STACK_GUESS=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  lang="$(python3 -c "import json,sys; d=json.load(open('$PROJECT_DIR/package.json')); f=d.get('dependencies',{}); f.update(d.get('devDependencies',{})); print(', '.join(list(f.keys())[:6]))" 2>/dev/null || true)"
  STACK_GUESS="Node.js${lang:+ ($lang)}"
elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  STACK_GUESS="Python (pyproject.toml)"
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  STACK_GUESS="Rust (Cargo)"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  MOD="$(head -1 "$PROJECT_DIR/go.mod" 2>/dev/null | awk '{print $2}')"
  STACK_GUESS="Go${MOD:+ ($MOD)}"
fi

CONVENTIONS=""
if [ -f "$PROJECT_DIR/.gitignore" ]; then
  CONVENTIONS="- .gitignore present"
fi
if [ -f "$PROJECT_DIR/package.json" ]; then
  SCRIPTS="$(python3 -c "import json,sys; d=json.load(open('$PROJECT_DIR/package.json')); s=d.get('scripts',{}); print(', '.join(list(s.keys())[:6]))" 2>/dev/null || true)"
  [ -n "$SCRIPTS" ] && CONVENTIONS="${CONVENTIONS:+$CONVENTIONS
}- npm scripts: $SCRIPTS"
fi

# ── Step 5: ask the user for project metadata ─────────────────────────────────

echo ""
echo "A few quick questions about your project:"
echo ""

prompt PROJECT_NAME "Project name"
prompt PROJECT_GOAL "Goal (one sentence)"
prompt PROJECT_STACK "Stack" "${STACK_GUESS:-unknown}"
prompt PROJECT_DEPLOY "Deployed on (e.g. Vercel, AWS, local only, not yet)"

# ── Step 6: write wiki/CONTEXT.md ────────────────────────────────────────────

if [ "$OVERWRITE" = true ] || [ ! -f "$PROJECT_DIR/wiki/CONTEXT.md" ]; then
  cp "$TPL_DIR/CONTEXT.md" "$PROJECT_DIR/wiki/CONTEXT.md"
  render_context \
    "$PROJECT_DIR/wiki/CONTEXT.md" \
    "$PROJECT_NAME" "$PROJECT_GOAL" "$PROJECT_STACK" "$PROJECT_DEPLOY" \
    "$TREE" "${CONVENTIONS:-none detected}"
  echo ""
  echo "  Wrote wiki/CONTEXT.md"
else
  echo ""
  echo "  wiki/CONTEXT.md already exists — skipping"
fi

# ── Step 7: write wiki/log.md ────────────────────────────────────────────────

if [ "$OVERWRITE" = true ] || [ ! -f "$PROJECT_DIR/wiki/log.md" ]; then
  cp "$TPL_DIR/log.md" "$PROJECT_DIR/wiki/log.md"
  echo "  Wrote wiki/log.md"
else
  echo "  wiki/log.md already exists — skipping"
fi

# ── Step 8: write rules to AGENTS.md (default) and optionally CLAUDE.md ──────

echo ""
echo "Writing wiki rules..."

write_rules "$PROJECT_DIR/AGENTS.md" "$TPL_DIR/rules.md.snippet"

echo ""
if yn "Also write the rules to CLAUDE.md? (enables bare keywords in Claude Code sessions)" "n"; then
  write_rules "$PROJECT_DIR/CLAUDE.md" "$TPL_DIR/rules.md.snippet"
fi

# ── Step 9: summary ──────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Your wiki is ready."
echo ""
echo "  wiki/CONTEXT.md   — project context"
echo "  wiki/log.md       — session log"
echo "  wiki/bugs/        — open/ and fixed/"
echo "  wiki/plans/       — active/, done/, abandoned/"
echo ""
echo "Open wiki/ as an Obsidian vault for graph view and backlinks."
echo ""
echo "Bare keywords (log, bug, status, read) now work in any"
echo "agentic tool session in this project."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
