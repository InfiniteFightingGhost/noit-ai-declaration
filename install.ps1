[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetProject
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $TargetProject -PathType Container)) {
    throw "target project folder not found: $TargetProject"
}
$target = (Resolve-Path -LiteralPath $TargetProject).Path
$repoRoot = $PSScriptRoot
$pluginDir = Join-Path $target ".opencode/plugins/noit"

$files = @(
    "index.ts",
    "config.ts",
    "types.ts",
    "backfill.ts",
    "db.ts",
    "export.ts",
    "check.ts",
    "redact.ts",
    "config.template.json",
    "config.local.template.json",
    "package.json",
    "README.md",
    "LICENSE",
    "CONTRIBUTING.md"
)

foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $name) -PathType Leaf)) {
        throw "missing file in this repository: $name (run sync.ps1 first)"
    }
}

[void](New-Item -ItemType Directory -Path $pluginDir -Force)
Write-Host "installing noit.ai-declaration into $pluginDir"

$copied = 0
$kept = 0
foreach ($name in $files) {
    $src = Join-Path $repoRoot $name
    $dst = Join-Path $pluginDir $name
    $existed = Test-Path -LiteralPath $dst -PathType Leaf
    if ($existed) {
        $srcBytes = [System.IO.File]::ReadAllBytes($src)
        $dstBytes = [System.IO.File]::ReadAllBytes($dst)
        if ([System.Linq.Enumerable]::SequenceEqual([byte[]]$srcBytes, [byte[]]$dstBytes)) {
            $kept++
            continue
        }
    }
    [System.IO.File]::WriteAllBytes($dst, [System.IO.File]::ReadAllBytes($src))
    $copied++
    if ($existed) { Write-Host "updated $name" } else { Write-Host "added $name" }
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm is required (Node.js 22.13+ with npm)"
}
Write-Host "running npm install in $pluginDir"
Push-Location $pluginDir
try {
    & npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$configPath = Join-Path $target ".noit/config.json"
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    Write-Host "existing .noit/config.json preserved (not modified)"
}

Write-Host "$copied files changed, $kept unchanged"

$opencodeJson = Join-Path $target "opencode.json"
if ((Test-Path -LiteralPath $opencodeJson -PathType Leaf) -and ((Get-Content -LiteralPath $opencodeJson -Raw) -match [regex]::Escape("./.opencode/plugins/noit"))) {
    Write-Host "opencode.json already references ./.opencode/plugins/noit"
} else {
    Write-Host ""
    Write-Host "Add this to $opencodeJson (merge the plugins array if the file already exists):"
    Write-Host '{'
    Write-Host '  "$schema": "https://opencode.ai/config.json",'
    Write-Host '  "plugins": ['
    Write-Host '    {'
    Write-Host '      "package": "./.opencode/plugins/noit",'
    Write-Host '      "options": {'
    Write-Host '        "backfill": {'
    Write-Host '          "scope": "project"'
    Write-Host '        }'
    Write-Host '      }'
    Write-Host '    }'
    Write-Host '  ]'
    Write-Host '}'
}

Write-Host ""
Write-Host "Next: restart opencode in $target, then verify with /noit-status."
