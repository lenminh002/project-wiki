# wiki-init — Claude Code skill

[![installs](https://img.shields.io/badge/dynamic/json?url=https://api.counterapi.dev/v1/lenminh/wiki-init&query=$.count&label=installs&color=blue)](https://api.counterapi.dev/v1/lenminh/wiki-init)

A Claude Code skill that bootstraps a persistent project wiki with:

- `wiki/` folder (`CONTEXT.md`, `log.md`, `bugs.md`, `plans/`)
- Bare-keyword commands that work in every future session: `log`, `bug`, `status`, `read`
- Auto-save of any multi-step plan to `wiki/plans/active/` — no prompting
- Cross-linked plans with relationship tags (`builds-on`, `depends-on`, `replaces`, …)
- Full Obsidian compatibility — open `wiki/` as a vault for graph view and backlinks

## Install

```bash
git clone https://github.com/lenminh002/project-wiki
cd project-wiki
./install.sh
```

Or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/lenminh002/project-wiki/main/install.sh | bash
```

## Use

Open any project in Claude Code and run:

```
/wiki-init
```

Claude will inspect your project, ask 4 questions (name, goal, stack, deploy target), scaffold the wiki folder, and patch your project's `CLAUDE.md` so the rules persist.

## What gets installed

```
~/.claude/skills/wiki-init/
  SKILL.md
  templates/
    CONTEXT.md
    log.md
    bugs.md
    CLAUDE.md.snippet
```

A trigger line is also added to `~/.claude/CLAUDE.md` so the skill auto-invokes when you type `/wiki-init`.

## Wiki folder structure

```
wiki/
  CONTEXT.md          — project name, goal, stack, conventions, folder tree
  log.md              — session-by-session log
  bugs.md             — open and fixed bugs
  plans/
    active/           — plans in progress (with YAML frontmatter + wikilinks)
    done/             — completed plans
    abandoned/        — plans we decided not to pursue
```

Open `wiki/` as an **Obsidian vault** to get the plan graph view and backlinks panel for free.

## Commands (active in every session after init)

| Say this | Claude does |
|---|---|
| `log` | Appends a session summary to `wiki/log.md` |
| `bug` | Adds an issue to `wiki/bugs.md` |
| `status` | Lists active plans, last 5 log entries, open bugs |
| `read` | Reads all wiki files, summarizes context, asks "What are we working on?" |

## Plan rules

- Any 3+-step plan is auto-saved to `wiki/plans/active/<feature>.md`
- Plans get YAML frontmatter: `status`, `created`, `updated`, `tags`, `related`
- New plans are cross-linked to related existing plans using `[[wikilinks]]`
- Moving a plan to `done/` or `abandoned/` updates its `status:` frontmatter; wikilinks survive the move
- Claude asks before moving a completed plan — never moves silently

## Uninstall

```bash
rm -rf ~/.claude/skills/wiki-init
# then remove the # wiki-init block from ~/.claude/CLAUDE.md
```
