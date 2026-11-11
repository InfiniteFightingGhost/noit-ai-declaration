[CmdletBinding()]
param(
    [string]$Source = (Join-Path (Split-Path -Parent $PSScriptRoot) "Raptor/.opencode/plugins/noit")
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = $PSScriptRoot
$verbatim = @(
    "index.ts",
    "config.ts",
    "types.ts",
    "backfill.ts",
    "db.ts",
    "export.ts",
    "check.ts",
    "redact.ts",
    "config.template.json",
    "config.local.template.json"
)

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "source plugin folder not found: $Source"
}
$sourceRoot = (Resolve-Path -LiteralPath $Source).Path

foreach ($name in $verbatim + @("package.json")) {
    $path = Join-Path $sourceRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "missing source file: $path"
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "node is required to rebuild package.json (Node.js 22.13+)"
}

Write-Host "sync: $sourceRoot -> $repoRoot"

$changed = 0
$unchanged = 0

foreach ($name in $verbatim) {
    $src = Join-Path $sourceRoot $name
    $dst = Join-Path $repoRoot $name
    $existed = Test-Path -LiteralPath $dst -PathType Leaf
    if ($existed) {
        $srcBytes = [System.IO.File]::ReadAllBytes($src)
        $dstBytes = [System.IO.File]::ReadAllBytes($dst)
        if ([System.Linq.Enumerable]::SequenceEqual([byte[]]$srcBytes, [byte[]]$dstBytes)) {
            $unchanged++
            continue
        }
    }
    [System.IO.File]::WriteAllBytes($dst, [System.IO.File]::ReadAllBytes($src))
    $changed++
    if ($existed) { Write-Host "updated $name" } else { Write-Host "added $name" }
}

$pkgJs = @'
let d = ""
process.stdin.setEncoding("utf8")
process.stdin.on("data", (c) => (d += c))
process.stdin.on("end", () => {
  const base = JSON.parse(d)
  const out = {
    name: "noit-ai-declaration",
    version: base.version,
    description: "opencode plugin that generates the Bulgarian НОИТ declaration «ДЕКЛАРАЦИЯ за използване на средства с изкуствен интелект (ИИ)» (Приложение 5) from real opencode session logs.",
    license: "MIT",
    type: base.type || "module",
    main: "index.ts",
    exports: base.exports || "./index.ts",
    files: [
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
      "README.md",
      "LICENSE",
      "CONTRIBUTING.md"
    ],
    dependencies: base.dependencies || {},
    repository: { type: "git", url: "https://github.com/InfiniteFightingGhost/noit-ai-declaration.git" },
    author: "InfiniteFightingGhost"
  }
  process.stdout.write(JSON.stringify(out, null, 2) + "\n")
})
'@

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$sourceJson = [System.IO.File]::ReadAllText((Join-Path $sourceRoot "package.json"), $utf8NoBom)
$merged = (($sourceJson | & node -e $pkgJs) -join "`n") + "`n"
if ($LASTEXITCODE -ne 0) { throw "node failed to rebuild package.json" }

$version = [regex]::Match($sourceJson, '"version"\s*:\s*"([^"]+)"').Groups[1].Value
$dstPkg = Join-Path $repoRoot "package.json"
$current = if (Test-Path -LiteralPath $dstPkg -PathType Leaf) { [System.IO.File]::ReadAllText($dstPkg, $utf8NoBom) } else { $null }
if ($current -ne $merged) {
    [System.IO.File]::WriteAllText($dstPkg, $merged, $utf8NoBom)
    $changed++
    Write-Host "updated package.json (version $version)"
} else {
    $unchanged++
}

$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
foreach ($name in $verbatim + @("package.json")) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot $name))
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "$name has a UTF-8 BOM"
    }
    try {
        [void]$utf8Strict.GetString($bytes)
    } catch {
        throw "$name is not valid UTF-8"
    }
}

$total = $verbatim.Count + 1
Write-Host "$total files checked, $changed changed, $unchanged unchanged"
