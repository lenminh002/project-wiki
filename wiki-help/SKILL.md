---
name: wiki-help
description: "Show a concise help cheat sheet for project-wiki commands when the user asks for /wiki-help, wiki-help, or help with wiki commands."
trigger: /wiki-help
---

# /wiki-help

Show the user a concise cheat sheet for project-wiki commands. This skill is read-only.

## Safety Boundaries

- Do not write files, modify wiki state, install dependencies, run project code, call network services, or inspect secret-bearing files.
- Do not read `.env*`, credential files, private keys, token files, or unrelated hidden files.
- If a project wiki exists, you may mention that project-local bare commands require AGENTS wiki rules from `/wiki-init`.

## Response

When invoked, respond with:

```markdown
## Wiki Commands

| Say this | Use it when you want to... |
|---|---|
| `/wiki-init` | Scaffold `wiki/` and optionally install project-local wiki rules. |
| `/wiki-help` | Show this command cheat sheet. |
| `read` | Load full wiki context, recent progress, active plans, and open bugs. |
| `status` | Check active plans, recent log entries, open bugs, and stale work. |
| `log` | Save a short summary of what happened in this session. |
| `bug` | Create a tracked bug note in `wiki/bugs/open/`. |
| `codemap` | Generate `wiki/code/<path>.md` files for source files so Obsidian can graph the codebase. |

Use `/wiki-init` first in a project that does not have `wiki/` yet. After AGENTS wiki rules are installed, the bare commands `read`, `status`, `log`, `bug`, and `codemap` work in future sessions.
```
