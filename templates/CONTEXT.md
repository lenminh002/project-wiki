# Project Context

Name: {{name}}
Goal: {{goal}}
Stack: {{stack}}
Deployed on: {{deployed_on}}

## Folder Structure
{{folder_structure}}

## Conventions
{{conventions}}

## Wiki Structure
```
wiki/
  CONTEXT.md        — this file
  log.md            — what happened each session
  bugs/
    open/           — one .md file per open bug
    fixed/          — fixed bugs
  plans/active/     — plans currently in progress
  plans/done/       — completed plans
  plans/abandoned/  — plans we decided not to pursue
```

> Open the `wiki/` folder as an Obsidian vault to get graph view of linked plans, backlinks panel, and Dataview queries across all plan frontmatter.

## Commands

| Command  | What the agent does                                     |
|----------|---------------------------------------------------------|
| log      | Append what we just did to log.md                       |
| bug      | Create a new bug file in wiki/bugs/open/                |
| status   | Summarize active plans, recent log, open bugs           |
| read     | Read all wiki files and summarize full project context  |
