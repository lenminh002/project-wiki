#!/usr/bin/env bash
set -e

SKILL_DIR="$HOME/.claude/skills/wiki-init"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
REPO="https://raw.githubusercontent.com/lenminh002/project-wiki/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing wiki-init skill..."

mkdir -p "$SKILL_DIR/templates"

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$SCRIPT_DIR/SKILL.md" ] && [ -f "$SCRIPT_DIR/templates/CLAUDE.md.snippet" ]; then
  cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
  cp -R "$SCRIPT_DIR/templates/." "$SKILL_DIR/templates/"
else
  curl -fsSL "$REPO/SKILL.md" -o "$SKILL_DIR/SKILL.md"
  curl -fsSL "$REPO/templates/CONTEXT.md"        -o "$SKILL_DIR/templates/CONTEXT.md"
  curl -fsSL "$REPO/templates/log.md"            -o "$SKILL_DIR/templates/log.md"
  curl -fsSL "$REPO/templates/CLAUDE.md.snippet" -o "$SKILL_DIR/templates/CLAUDE.md.snippet"
fi

echo "  Copied skill files to $SKILL_DIR"

# Register trigger in ~/.claude/CLAUDE.md
TRIGGER_BLOCK="# wiki-init
- **wiki-init** (\`~/.claude/skills/wiki-init/SKILL.md\`) - scaffold project wiki with linked plans, Obsidian support, and persistent bare-keyword commands. Trigger: \`/wiki-init\`
When the user types \`/wiki-init\`, invoke the Skill tool with \`skill: \"wiki-init\"\` before doing anything else."

if [ ! -f "$CLAUDE_MD" ]; then
  echo "$TRIGGER_BLOCK" > "$CLAUDE_MD"
  echo "  Created $CLAUDE_MD with wiki-init trigger"
elif grep -qE "^# wiki-init$" "$CLAUDE_MD"; then
  echo "  Trigger already present in $CLAUDE_MD — skipping"
else
  echo "" >> "$CLAUDE_MD"
  echo "$TRIGGER_BLOCK" >> "$CLAUDE_MD"
  echo "  Added wiki-init trigger to $CLAUDE_MD"
fi

curl -sf "https://api.counterapi.dev/v1/lenminh/wiki-init/up" >/dev/null 2>&1 &

echo ""
echo "Done. Open any project in Claude Code and run /wiki-init to get started."
