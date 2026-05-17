# wiki-init — standalone project wiki bootstrap (Windows / PowerShell)
# Works with any agentic coding tool that reads AGENTS.md or CLAUDE.md.
# Usage:
#   irm https://raw.githubusercontent.com/lenminh002/project-wiki/main/wiki-init.ps1 | iex
#   # or from a clone: .\wiki-init.ps1

$ErrorActionPreference = "Stop"

$Repo       = "https://raw.githubusercontent.com/lenminh002/project-wiki/main"
$ProjectDir = (Get-Location).Path
$utf8NoBom  = New-Object System.Text.UTF8Encoding $false

# Detect adjacent templates/ (clone run vs remote pipe)
$ScriptDir = $null
if ($PSCommandPath) { $ScriptDir = Split-Path -Parent $PSCommandPath }

# ── helpers ──────────────────────────────────────────────────────────────────

function Prompt-User($Message, $Default = "") {
  if ($Default) { Write-Host -NoNewline "$Message [$Default]: " }
  else          { Write-Host -NoNewline "${Message}: " }
  $input = Read-Host
  if (-not $input -and $Default) { return $Default }
  return $input
}

function Prompt-YN($Message, $Default = "n") {
  $hint = if ($Default -eq "y") { "Y/n" } else { "y/N" }
  Write-Host -NoNewline "$Message [$hint]: "
  $input = Read-Host
  if (-not $input) { $input = $Default }
  return $input -match "^[Yy]"
}

function Fetch-Template($Name, $Dest) {
  $local = if ($ScriptDir) { Join-Path $ScriptDir "templates\$Name" } else { $null }
  if ($local -and (Test-Path $local)) {
    Copy-Item -LiteralPath $local -Destination $Dest -Force
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri "$Repo/templates/$Name" -OutFile $Dest
  }
}

function Write-Rules($Target, $Snippet) {
  $snippetContent = [System.IO.File]::ReadAllText($Snippet)
  if (Test-Path $Target) {
    $existing = [System.IO.File]::ReadAllText($Target)
    if ($existing -match "# Wiki workflow") {
      Write-Host "  $Target already contains wiki rules — skipping (idempotent)"
      return
    }
    if (-not $existing.EndsWith("`n")) { $existing += "`n" }
    [System.IO.File]::WriteAllText($Target, $existing + "`n" + $snippetContent, $utf8NoBom)
    Write-Host "  Appended wiki rules to $Target"
  } else {
    [System.IO.File]::WriteAllText($Target, $snippetContent, $utf8NoBom)
    Write-Host "  Created $Target with wiki rules"
  }
}

# ── Step 1: check for existing wiki ──────────────────────────────────────────

$Overwrite = $false
if (Test-Path (Join-Path $ProjectDir "wiki")) {
  Write-Host "A wiki/ folder already exists in this project."
  $choice = Prompt-User "What would you like to do? [skip / overwrite / cancel]" "skip"
  switch ($choice.ToLower()) {
    "overwrite" { $Overwrite = $true }
    "cancel"    { Write-Host "Cancelled."; exit 0 }
    default     { Write-Host "Leaving existing wiki/ untouched." }
  }
}

# ── Step 2: scaffold folder tree ─────────────────────────────────────────────

Write-Host ""
Write-Host "Scaffolding wiki/ folder..."

$Dirs = @(
  "wiki\bugs\open", "wiki\bugs\fixed",
  "wiki\plans\active", "wiki\plans\done", "wiki\plans\abandoned"
)
foreach ($d in $Dirs) {
  $full = Join-Path $ProjectDir $d
  New-Item -ItemType Directory -Force -Path $full | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $full ".gitkeep"), "", $utf8NoBom)
}
Write-Host "  Created wiki/ directory tree"

# ── Step 3: fetch templates ───────────────────────────────────────────────────

$TplDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wiki-init-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $TplDir | Out-Null

Fetch-Template "CONTEXT.md"       (Join-Path $TplDir "CONTEXT.md")
Fetch-Template "log.md"           (Join-Path $TplDir "log.md")
Fetch-Template "rules.md.snippet" (Join-Path $TplDir "rules.md.snippet")

# ── Step 4: inspect the project ──────────────────────────────────────────────

$TreeItems  = Get-ChildItem -Path $ProjectDir -Name | Where-Object { $_ -ne "wiki" } | Select-Object -First 30
$TreeString = ($TreeItems | ForEach-Object { "  $_" }) -join "`n"

$StackGuess = ""
if (Test-Path (Join-Path $ProjectDir "package.json")) {
  $StackGuess = "Node.js"
} elseif (Test-Path (Join-Path $ProjectDir "pyproject.toml")) {
  $StackGuess = "Python (pyproject.toml)"
} elseif (Test-Path (Join-Path $ProjectDir "Cargo.toml")) {
  $StackGuess = "Rust (Cargo)"
} elseif (Test-Path (Join-Path $ProjectDir "go.mod")) {
  $StackGuess = "Go"
}

# ── Step 5: ask the user for project metadata ─────────────────────────────────

Write-Host ""
Write-Host "A few quick questions about your project:"
Write-Host ""

$ProjectName   = Prompt-User "Project name"
$ProjectGoal   = Prompt-User "Goal (one sentence)"
$ProjectStack  = Prompt-User "Stack" $StackGuess
$ProjectDeploy = Prompt-User "Deployed on (e.g. Vercel, AWS, local only, not yet)"

# ── Step 6: write wiki/CONTEXT.md ────────────────────────────────────────────

$ContextDest = Join-Path $ProjectDir "wiki\CONTEXT.md"
if ($Overwrite -or -not (Test-Path $ContextDest)) {
  $content = [System.IO.File]::ReadAllText((Join-Path $TplDir "CONTEXT.md"))
  $content = $content `
    -replace "\{\{name\}\}",             $ProjectName `
    -replace "\{\{goal\}\}",             $ProjectGoal `
    -replace "\{\{stack\}\}",            $ProjectStack `
    -replace "\{\{deployed_on\}\}",      $ProjectDeploy `
    -replace "\{\{folder_structure\}\}", $TreeString `
    -replace "\{\{conventions\}\}",      "none detected"
  [System.IO.File]::WriteAllText($ContextDest, $content, $utf8NoBom)
  Write-Host ""
  Write-Host "  Wrote wiki/CONTEXT.md"
} else {
  Write-Host ""
  Write-Host "  wiki/CONTEXT.md already exists — skipping"
}

# ── Step 7: write wiki/log.md ────────────────────────────────────────────────

$LogDest = Join-Path $ProjectDir "wiki\log.md"
if ($Overwrite -or -not (Test-Path $LogDest)) {
  Copy-Item -LiteralPath (Join-Path $TplDir "log.md") -Destination $LogDest -Force
  Write-Host "  Wrote wiki/log.md"
} else {
  Write-Host "  wiki/log.md already exists — skipping"
}

# ── Step 8: write rules to AGENTS.md and optionally CLAUDE.md ────────────────

Write-Host ""
Write-Host "Writing wiki rules..."

Write-Rules (Join-Path $ProjectDir "AGENTS.md") (Join-Path $TplDir "rules.md.snippet")

Write-Host ""
if (Prompt-YN "Also write the rules to CLAUDE.md? (enables bare keywords in Claude Code sessions)" "n") {
  Write-Rules (Join-Path $ProjectDir "CLAUDE.md") (Join-Path $TplDir "rules.md.snippet")
}

# Cleanup temp dir
Remove-Item -Recurse -Force $TplDir

# ── Step 9: summary ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("━" * 48)
Write-Host "Your wiki is ready."
Write-Host ""
Write-Host "  wiki/CONTEXT.md   — project context"
Write-Host "  wiki/log.md       — session log"
Write-Host "  wiki/bugs/        — open/ and fixed/"
Write-Host "  wiki/plans/       — active/, done/, abandoned/"
Write-Host ""
Write-Host "Open wiki/ as an Obsidian vault for graph view and backlinks."
Write-Host ""
Write-Host "Bare keywords (log, bug, status, read) now work in any"
Write-Host "agentic tool session in this project."
Write-Host ("━" * 48)
