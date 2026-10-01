param(
 [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive',
 [string]$AssetRoot = '',
 [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$game = [IO.Path]::GetFullPath((Join-Path $GameRoot 'game\csgo'))
if (-not (Test-Path -LiteralPath (Join-Path $game 'bin\win64\client.dll'))) { throw 'GameRoot must identify a CS2 installation.' }
if (-not $AssetRoot) {
 $adjacentAssets = Join-Path $PSScriptRoot 'assets\vfx'
 $sourceAssets = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\vfx'
 $AssetRoot = if (Test-Path -LiteralPath (Join-Path $adjacentAssets 'manifest.json')) { $adjacentAssets } else { $sourceAssets }
}
$assets = [IO.Path]::GetFullPath($AssetRoot)
$manifest = Get-Content -LiteralPath (Join-Path $assets 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.version -ne 1 -or -not $manifest.files -or @($manifest.files.PSObject.Properties).Count -eq 0) { throw 'VFX manifest must contain version 1 and a nonempty file list.' }
$jobs = @()
foreach ($file in $manifest.files.PSObject.Properties) {
 $relative = $file.Name.Replace('/','\')
 if ($relative -notmatch '^(materials|particles)\\scooby_vfx\\[a-z0-9_\\]+\.(vtex|vmat|vpcf)_c$') { throw "Unexpected asset path: $relative" }
 $source = [IO.Path]::GetFullPath((Join-Path $assets $relative))
 $target = [IO.Path]::GetFullPath((Join-Path $game $relative))
 if (-not $source.StartsWith($assets + '\', [StringComparison]::OrdinalIgnoreCase) -or -not $target.StartsWith($game + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Asset path escaped its root.' }
 if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.Value) { throw "Source checksum mismatch: $relative" }
 $parent = Split-Path -Parent $target
 while ($parent -and $parent.StartsWith($game, [StringComparison]::OrdinalIgnoreCase)) {
  if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked directory: $parent" }
  $parent = Split-Path -Parent $parent
 }
 if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked target: $target" }
 $jobs += [PSCustomObject]@{ Source=$source; Target=$target; Hash=$file.Value }
}
foreach ($job in $jobs) {
 if (-not $VerifyOnly) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $job.Target) -Force | Out-Null
  Copy-Item -LiteralPath $job.Source -Destination $job.Target -Force
 }
 if ((Get-FileHash -LiteralPath $job.Target -Algorithm SHA256).Hash -ne $job.Hash) { throw "Installed checksum mismatch: $($job.Target)" }
}
Write-Output "Verified $($jobs.Count) VFX resources in $game"
