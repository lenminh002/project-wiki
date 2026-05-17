#!/usr/bin/env bash
# wiki-init — standalone project wiki bootstrap
# Works with any agentic coding tool that reads AGENTS.md or CLAUDE.md.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lenminh002/project-wiki/main/wiki-init.sh | bash
#   # or from a clone: ./wiki-init.sh
set -e

REPO="https://raw.githubusercontent.com/lenminh002/project-wiki/main"
PROJECT_DIR="$(pwd)"

# Detect clone-local run vs remote pipe: only use local templates if this
# script was invoked as a real file (not piped through bash) and the
# templates directory actually sits next to it.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  _candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [ -f "$_candidate/templates/rules.md.snippet" ]; then
    SCRIPT_DIR="$_candidate"
  fi
  unset _candidate
fi

# helpers 

# Determine the best input source: prefer /dev/tty (works even when stdin is
# a pipe) but fall back to stdin for non-interactive environments.
if [ -t 0 ]; then
  _TTY=/dev/stdin
elif [ -e /dev/tty ]; then
  _TTY=/dev/tty
else
  _TTY=/dev/stdin
fi

prompt() {
  # prompt <var_name> <message> [default]
  local var="$1" msg="$2" default="${3:-}"
  if [ -n "$default" ]; then
    printf "%s [%s]: " "$msg" "$default" >&2
  else
    printf "%s: " "$msg" >&2
  fi
  local input
  read -r input <"$_TTY" || true
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
  read -r input <"$_TTY" || true
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
  # Substitute {{placeholders}} in the template file in-place.
  # Values are passed via argv (python3) or temp files (awk) to safely handle
  # spaces, newlines, |, &, and \ in paths and user-provided strings.
  local file="$1"
  local name="$2" goal="$3" stack="$4" deployed="$5" tree="$6" conventions="$7"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$name" "$goal" "$stack" "$deployed" "$conventions" <<PYEOF
import sys, pathlib, os
f, name, goal, stack, deployed, conventions = sys.argv[1:]
tree = os.environ.get("_WIKI_TREE", "")
content = pathlib.Path(f).read_text()
content = content.replace("{{name}}", name)
content = content.replace("{{goal}}", goal)
content = content.replace("{{stack}}", stack)
content = content.replace("{{deployed_on}}", deployed)
content = content.replace("{{folder_structure}}", tree)
content = content.replace("{{conventions}}", conventions)
pathlib.Path(f).write_text(content)
PYEOF
  else
    # python3 not found — write multiline values to temp files so awk can read
    # them safely (awk -v strips newlines, making it unusable for $tree/$conventions)
    local tmp tree_file conv_file
    tmp="$(mktemp)"
    tree_file="$(mktemp)"
    conv_file="$(mktemp)"
    printf '%s' "$tree"         > "$tree_file"
    printf '%s' "$conventions"  > "$conv_file"
    awk -v name="$name" -v goal="$goal" -v stack="$stack" -v dep="$deployed" \
        -v tf="$tree_file" -v cf="$conv_file" '
    BEGIN {
      while ((getline line < tf) > 0) tree = tree (tree ? "\n" : "") line
      close(tf)
      while ((getline line < cf) > 0) conv = conv (conv ? "\n" : "") line
      close(cf)
    }
    { gsub(/\{\{name\}\}/, name)
      gsub(/\{\{goal\}\}/, goal)
      gsub(/\{\{stack\}\}/, stack)
      gsub(/\{\{deployed_on\}\}/, dep)
      gsub(/\{\{folder_structure\}\}/, tree)
      gsub(/\{\{conventions\}\}/, conv)
      print }' "$file" > "$tmp"
    mv "$tmp" "$file"
    rm -f "$tree_file" "$conv_file"
  fi
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

# Step 1: check for existing wiki 

OVERWRITE=false
if [ -d "$PROJECT_DIR/wiki" ]; then
  echo "A wiki/ folder already exists in this project."
  printf "What would you like to do? [skip / overwrite / cancel] (default: skip): " >&2
  read -r choice <"$_TTY" || true
  choice="${choice:-skip}"
  case "$choice" in
    overwrite) OVERWRITE=true ;;
    cancel)    echo "Cancelled."; exit 0 ;;
    *)         echo "Leaving existing wiki/ untouched."; OVERWRITE=false ;;
  esac
fi

# Step 2: scaffold folder tree 

if [ ! -d "$PROJECT_DIR/wiki" ] || [ "$OVERWRITE" = true ]; then
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
fi

# Step 3: fetch templates to a temp dir 

TPL_DIR="$(mktemp -d)"
trap 'rm -rf "$TPL_DIR"' EXIT

fetch_template "CONTEXT.md"       "$TPL_DIR/CONTEXT.md"
fetch_template "log.md"           "$TPL_DIR/log.md"
fetch_template "rules.md.snippet" "$TPL_DIR/rules.md.snippet"

# Step 4: inspect the project 

TREE="$(ls -1A "$PROJECT_DIR" 2>/dev/null | grep -v '^wiki$' | head -30 | sed 's/^/  /')"

STACK_GUESS=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  lang="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
f=d.get('dependencies',{})
f.update(d.get('devDependencies',{}))
print(', '.join(list(f.keys())[:6]))
" "$PROJECT_DIR/package.json" 2>/dev/null || true)"
  STACK_GUESS="Node.js${lang:+ ($lang)}"
elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  STACK_GUESS="Python (pyproject.toml)"
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  STACK_GUESS="Rust (Cargo)"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  MOD="$(grep -m1 '^module ' "$PROJECT_DIR/go.mod" 2>/dev/null | awk '{print $2}')"
  STACK_GUESS="Go${MOD:+ ($MOD)}"
fi

CONVENTIONS=""
if [ -f "$PROJECT_DIR/.gitignore" ]; then
  CONVENTIONS="- .gitignore present"
fi
if [ -f "$PROJECT_DIR/package.json" ]; then
  SCRIPTS="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
s=d.get('scripts',{})
print(', '.join(list(s.keys())[:6]))
" "$PROJECT_DIR/package.json" 2>/dev/null || true)"
  [ -n "$SCRIPTS" ] && CONVENTIONS="${CONVENTIONS:+$CONVENTIONS
}- npm scripts: $SCRIPTS"
fi

# Step 5: ask the user for project metadata 

echo ""
echo "A few quick questions about your project:"
echo ""

prompt PROJECT_NAME "Project name"
prompt PROJECT_GOAL "Goal (one sentence)"
prompt PROJECT_STACK "Stack" "${STACK_GUESS:-unknown}"
prompt PROJECT_DEPLOY "Deployed on (e.g. Vercel, AWS, local only, not yet)"

# Step 6: write wiki/CONTEXT.md 

if [ "$OVERWRITE" = true ] || [ ! -f "$PROJECT_DIR/wiki/CONTEXT.md" ]; then
  cp "$TPL_DIR/CONTEXT.md" "$PROJECT_DIR/wiki/CONTEXT.md"
  _WIKI_TREE="$TREE" render_context \
    "$PROJECT_DIR/wiki/CONTEXT.md" \
    "$PROJECT_NAME" "$PROJECT_GOAL" "$PROJECT_STACK" "$PROJECT_DEPLOY" \
    "$TREE" "${CONVENTIONS:-none detected}"
  echo ""
  echo "  Wrote wiki/CONTEXT.md"
else
  echo ""
  echo "  wiki/CONTEXT.md already exists — skipping"
fi

# Step 7: write wiki/log.md 

if [ "$OVERWRITE" = true ] || [ ! -f "$PROJECT_DIR/wiki/log.md" ]; then
  cp "$TPL_DIR/log.md" "$PROJECT_DIR/wiki/log.md"
  echo "  Wrote wiki/log.md"
else
  echo "  wiki/log.md already exists — skipping"
fi

# Step 8: write rules to AGENTS.md (default) and optionally CLAUDE.md 

echo ""
echo "Writing wiki rules..."

write_rules "$PROJECT_DIR/AGENTS.md" "$TPL_DIR/rules.md.snippet"

echo ""
if yn "Also write the rules to CLAUDE.md? (enables bare keywords in Claude Code sessions)" "n"; then
  write_rules "$PROJECT_DIR/CLAUDE.md" "$TPL_DIR/rules.md.snippet"
fi

# Step 9: summary 

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
