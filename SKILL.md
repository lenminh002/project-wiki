---
name: wiki-init
description: "Scaffold a wiki/ folder with CONTEXT.md, log.md, bugs/{open,fixed}/, plans/{active,done,abandoned}/ and install rules into project AGENTS.md by default so bare keywords log/bug/status/read work in future agent sessions. Also Obsidian-compatible with wikilinks and YAML frontmatter on every plan and bug."
trigger: /wiki-init
---

# /wiki-init

Bootstrap a persistent project wiki with Obsidian-compatible linked plans, auto-plan saving, and bare-keyword commands (`log`, `bug`, `status`, `read`) that survive across future agent sessions that read the project rules file.

## Usage

```
/wiki-init    # run in any project root — no arguments needed
```

## What You Must Do When Invoked

Follow these steps in order. Do not skip steps.

### Step 1 — Check for existing wiki

Run `ls ./wiki 2>/dev/null` to see if a `wiki/` folder already exists.

- If it exists: ask the user whether to skip (leave existing files untouched), overwrite (replace all files), or cancel. Do not proceed until the user answers. If they say skip or cancel, stop here.
- If it does not exist: continue.

### Step 2 — Create folder structure

Create the following directories and placeholder files:

```
wiki/
wiki/bugs/
wiki/bugs/open/
wiki/bugs/fixed/
wiki/plans/
wiki/plans/active/
wiki/plans/done/
wiki/plans/abandoned/
```

Write a `.gitkeep` file into each of the `bugs/` and `plans/` subdirectories so they are committed by git even when empty.

### Step 3 — Copy seed files

Read the template file from the skill's `templates/` directory (relative to this SKILL.md file: `templates/log.md`) and write it verbatim to `wiki/log.md`.

The skill's templates directory is relative to this `SKILL.md` file.

### Step 4 — Inspect the project

Run `ls -1A` in the project root. Also attempt to read these files if they exist (do not error if missing):
- `package.json`
- `pyproject.toml`
- `Cargo.toml`
- `go.mod`
- `README.md`
- `.gitignore`
- `vercel.json`, `netlify.toml`, `fly.toml`, `render.yaml`, `railway.toml`, `Dockerfile`, `docker-compose.yml`

From what you find, infer:
- **Stack**: language, framework, major dependencies
- **Folder Structure**: a tree of the top-level directories with a one-line description of each
- **Conventions**: naming patterns, test location, config file conventions, anything notable in .gitignore or tooling config

Prepare these three values to insert into CONTEXT.md.

### Step 5 — Derive project metadata from scan (no questions)

Using only what you found in Step 4, determine:

1. **Project name** — in order of preference: `package.json` `.name`, `pyproject.toml` `[project] name`, `go.mod` module path (last segment), README first `#` heading, current directory name.
2. **Project goal** — in order of preference: `package.json` `.description`, `pyproject.toml` `[project] description`, first non-heading paragraph in README, or `"(not specified)"` if none found.
3. **Stack** — what you already inferred in Step 4.
4. **Deployed on** — check for these files and map to a label:
   - `vercel.json` or `.vercel/` → "Vercel"
   - `netlify.toml` or `netlify.yml` → "Netlify"
   - `fly.toml` → "Fly.io"
   - `render.yaml` → "Render"
   - `Dockerfile` or `docker-compose.yml` → "Docker"
   - `.github/workflows/` containing `deploy` → "GitHub Actions"
   - `railway.toml` or `railway.json` → "Railway"
   - Nothing found → "not yet"

Do not ask the user anything in this step. Proceed directly to Step 6.

### Step 6 — Write wiki/CONTEXT.md

Read `templates/CONTEXT.md` from this skill's install directory.

Replace the following placeholders with real values:
- `{{name}}` → project name from Step 5
- `{{goal}}` → project goal from Step 5
- `{{stack}}` → stack from Step 5
- `{{deployed_on}}` → deployment from Step 5
- `{{folder_structure}}` → a fenced code block with the tree you built in Step 4
- `{{conventions}}` → a bulleted list of conventions from Step 4

Write the result to `wiki/CONTEXT.md`.

### Step 7 — Write the wiki rules to the project rules file

Read `templates/rules.md.snippet` from this skill's install directory.

**Default: write to `./AGENTS.md`** (read by Codex CLI, Aider, Jules, recent Cursor, and many other agentic tools).

- Check whether `./AGENTS.md` exists.
  - If it contains `# Wiki workflow` already → skip (idempotent, don't duplicate).
  - If it exists but lacks the block → append the snippet to the end.
  - If it does not exist → create it with the snippet as its entire content.

Then ask: **"Also write the rules to CLAUDE.md? (This lets bare keywords work in Claude Code sessions in this project.)"** with options: **Yes** / **No (AGENTS.md is enough)**.

If the user says Yes:
- Check whether `./CLAUDE.md` exists.
  - If it contains `# Wiki workflow` already → skip (idempotent).
  - If it exists but lacks the block → append the snippet.
  - If it does not exist → create it with the snippet as its entire content.

### Step 8 — Confirm to the user

Print a confirmation listing every file and folder created, and which rules files were written or skipped (AGENTS.md and/or CLAUDE.md), then add:

> Your wiki is ready. Open `wiki/` as an Obsidian vault to get graph view of linked plans and backlinks.
> AGENTS.md has been updated — bare keywords `log`, `bug`, `status`, and `read` will work in any agentic coding tool session in this project.

Then ask: **"What are we working on?"**

## Idempotency Guarantee

- Never overwrite `wiki/log.md`, `wiki/CONTEXT.md`, or the `wiki/bugs/` folder if they already exist (unless the user explicitly said "overwrite" in Step 1).
- Never duplicate the `# Wiki workflow` section in CLAUDE.md.
- The `.gitkeep` files are safe to overwrite (they're empty).

## Templates Location

All templates are in the `templates/` directory next to this `SKILL.md`:
- `CONTEXT.md` — project context template with `{{placeholders}}`
- `log.md` — seed session log
- `rules.md.snippet` — rules block that makes bare keywords and auto-plan saving work

## What the Installed Rules Do

Once the project rules file is updated, the following behaviors are active in every future agent session that reads it — no skill invocation needed:

| Bare keyword | What the agent does |
|---|---|
| `log` | Appends a session summary entry to `wiki/log.md` |
| `bug` | Creates a new `wiki/bugs/open/<slug>.md` file with frontmatter and body |
| `status` | Lists active plans, last 5 log entries, open bugs |
| `read` | Reads all wiki files and summarizes project state, then asks "What are we working on?" |
| `codemap` | Asks which folder(s) to scan, then generates one `wiki/code/<path>.md` per source file with purpose, functions, and import wikilinks — viewable as a code dependency graph in Obsidian |

**Auto-plan rule**: any response with 3+ steps for building something is automatically saved to `wiki/plans/active/<feature>.md` with YAML frontmatter (`status`, `created`, `updated`, `tags`, `related`) — no need to ask.

**Plan linking**: when saving a new plan, the agent scans existing plans for related ones and cross-links them using `[[wikilinks]]` and relationship tags (`builds-on`, `depends-on`, `replaces`, etc.). These wikilinks work natively in Obsidian's graph view and backlinks panel.
