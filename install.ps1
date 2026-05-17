# wiki-init installer for Windows (PowerShell)
# Run:  irm https://cdn.jsdelivr.net/gh/lenminh002/project-wiki@main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$SkillDir = Join-Path $HOME ".claude\skills\wiki-init"
$TplDir   = Join-Path $SkillDir "templates"
$ClaudeMd = Join-Path $HOME ".claude\CLAUDE.md"
$Repo     = "https://raw.githubusercontent.com/lenminh002/project-wiki/main"

Write-Host "Installing wiki-init skill..."

New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
New-Item -ItemType Directory -Force -Path $TplDir   | Out-Null

# Detect whether we're running from a cloned repo or via `irm | iex`.
$ScriptDir = $null
if ($PSCommandPath) {
  $ScriptDir = Split-Path -Parent $PSCommandPath
}

$Templates = @("CONTEXT.md", "log.md", "CLAUDE.md.snippet")

if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "SKILL.md"))) {
  Copy-Item -LiteralPath (Join-Path $ScriptDir "SKILL.md") -Destination (Join-Path $SkillDir "SKILL.md") -Force
  foreach ($f in $Templates) {
    Copy-Item -LiteralPath (Join-Path $ScriptDir "templates\$f") -Destination (Join-Path $TplDir $f) -Force
  }
} else {
  Invoke-WebRequest -UseBasicParsing -Uri "$Repo/SKILL.md" -OutFile (Join-Path $SkillDir "SKILL.md")
  foreach ($f in $Templates) {
    Invoke-WebRequest -UseBasicParsing -Uri "$Repo/templates/$f" -OutFile (Join-Path $TplDir $f)
  }
}

Write-Host "  Copied skill files to $SkillDir"

# Register trigger in ~/.claude/CLAUDE.md
$TriggerBlock = @"
# wiki-init
- **wiki-init** (``~/.claude/skills/wiki-init/SKILL.md``) - scaffold project wiki with linked plans, Obsidian support, and persistent bare-keyword commands. Trigger: ``/wiki-init``
When the user types ``/wiki-init``, invoke the Skill tool with ``skill: "wiki-init"`` before doing anything else.
"@

# WriteAllText emits UTF-8 without BOM on all PS versions.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path $ClaudeMd)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ClaudeMd) | Out-Null
  [System.IO.File]::WriteAllText($ClaudeMd, $TriggerBlock + "`n", $utf8NoBom)
  Write-Host "  Created $ClaudeMd with wiki-init trigger"
} elseif (Select-String -Path $ClaudeMd -Pattern "^# wiki-init$" -Quiet) {
  Write-Host "  Trigger already present in $ClaudeMd - skipping"
} else {
  $existing = [System.IO.File]::ReadAllText($ClaudeMd)
  if (-not $existing.EndsWith("`n")) { $existing += "`n" }
  [System.IO.File]::WriteAllText($ClaudeMd, $existing + "`n" + $TriggerBlock + "`n", $utf8NoBom)
  Write-Host "  Added wiki-init trigger to $ClaudeMd"
}

# Fire-and-forget install counter (inline; ~ms).
try {
  Invoke-WebRequest -UseBasicParsing -Uri "https://api.counterapi.dev/v1/lenminh/wiki-init/up" -TimeoutSec 3 | Out-Null
} catch {}

Write-Host ""
Write-Host "Done. Open any project in Claude Code and run /wiki-init to get started."
