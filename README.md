# project-wiki — project wiki skill for agentic coding tools

[![skills.sh](https://skills.sh/b/lenminh002/project-wiki)](https://skills.sh/lenminh002/project-wiki)

A skill for agentic coding tools that builds a project wiki — persists context across sessions, auto-saves plans, tracks bugs, logs progress, and maps your codebase. Obsidian compatible.

Bootstraps a persistent project wiki that works with **any agentic coding tool** — Codex CLI, Aider, Jules, Cursor, Claude Code, and more:

- `wiki/` folder (`CONTEXT.md`, `log.md`, `bugs/`, `plans/`)
- Optional project-local commands for future sessions: `/wiki-help`, `log`, `bug`, `status`, `read`
- Saves multi-step plans to `wiki/plans/active/` for continuity
- **AI detects relationships** — the agent checks existing wiki content and links new plans and bugs to related ones using `[[wikilinks]]` and tags (`builds-on`, `depends-on`, `replaces`, ...)
- `codemap` generates `wiki/code/` entries for source files, including HTML/CSS links
- Full Obsidian compatibility — open `wiki/` as a vault for graph view and backlinks

## Install

Install the skill globally with the cross-agent skills CLI:

### macOS / Linux

```bash
npx skills add lenminh002/project-wiki --skill wiki-init --global
```

### Windows (PowerShell)

```powershell
npx skills add lenminh002/project-wiki --skill wiki-init --global
```

Then open any project in a supported agent and run:

```
/wiki-init
```

The agent detects your project's name, stack, and deploy target from non-secret metadata files, scaffolds `wiki/`, and asks before writing optional project-local rules to `AGENTS.md`.

Run `/wiki-help` anytime for a quick command cheat sheet.

Existing projects with an older `# Wiki workflow` block should rerun `/wiki-init` or manually refresh that block to get the latest safety and `codemap` rules.

---

## Wiki folder structure

```
wiki/
  CONTEXT.md          — project name, goal, stack, conventions, folder tree
  log.md              — session-by-session log
  bugs/
    open/             — one .md file per open bug (YAML frontmatter + wikilinks)
    fixed/            — fixed bugs (moved from open/, status: fixed)
  plans/
    active/           — plans in progress (with YAML frontmatter + wikilinks)
    done/             — completed plans
    abandoned/        — plans we decided not to pursue
  code/               — generated code graph files from `codemap`
```

Open `wiki/` as an **Obsidian vault** to get the plan graph view and backlinks panel.

## Skill repository layout

```
wiki-init/
  SKILL.md
  templates/
    CONTEXT.md
    log.md
    rules.md.snippet
```

## Commands (active after AGENTS.md rules are approved)

| Say this | The agent does |
|---|---|
| `/wiki-help` | Shows the wiki command cheat sheet |
| `log` | Appends a session summary to `wiki/log.md` |
| `bug` | Creates a new file in `wiki/bugs/open/` with frontmatter and wikilink support |
| `status` | Lists active plans, last 5 log entries, open bugs |
| `read` | Reads all wiki files, summarizes context, asks "What are we working on?" |
| `codemap` | Generates one `wiki/code/<path>.md` per source file — purpose, functions/sections, and import/link wikilinks |

## Code graph (`codemap`)

Type `codemap` in any session and the agent will:

1. Ask which folder(s) to inspect
2. Walk only the chosen folders (respecting `.gitignore`, skipping hidden folders, secrets, `node_modules/`, `dist/`, etc.)
3. Write one `wiki/code/<mirrored-path>.md` per source file, including HTML and CSS, each containing:
   - **Purpose** — one-line summary of what the file does
   - **Functions / Sections** — bulleted list with one-line descriptions
   - **Imports / Links** — in-repo imports, local HTML links, local scripts/stylesheets/assets, CSS `@import`, and CSS `url(...)` as `[[wikilinks]]`; third-party imports/CDNs as `external: package-name`

Open `wiki/` as an Obsidian vault and the graph view shows your **entire codebase as a dependency graph** — source files as nodes, imports and local links as edges — sitting alongside your plans and bug nodes.

Re-run `codemap` anytime to refresh. When the agent edits a source file that already has a `wiki/code/` entry, it keeps that entry up to date.

## Plan rules

- Any 3+-step plan is saved to `wiki/plans/active/<feature>.md`
- Plans get YAML frontmatter: `status`, `created`, `updated`, `tags`, `related`
- **The agent checks existing plans and bugs**, detects semantic relationships, and adds wikilinks
- Relationship tags (`builds-on`, `depends-on`, `replaces`, `related-to`) are inferred from content and context
- Moving a plan to `done/` or `abandoned/` updates its `status:` frontmatter; wikilinks survive the move
- The agent asks before moving a completed plan.

## Uninstall

Remove `AGENTS.md` (or the `# Wiki Bootstrap Rule` / `# Wiki workflow` blocks from it) and remove the `wiki/` folder from your project.

If you installed the persistent trigger with `npx skills add`, use your skills CLI or agent's skill directory to remove the global `wiki-init` skill.

```bash
npx skills remove wiki-init --global
```

```powershell
npx skills remove wiki-init --global
```
