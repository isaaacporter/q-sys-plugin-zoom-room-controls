<#
.SYNOPSIS
  Packs the compiled plugin as a Q-SYS Personal Package and updates the feed.

.DESCRIPTION
  Q-SYS Library "Personal Packages" read a NuGet v3 registration index.
  This script:
    1. reads the plugin BuildVersion from info.lua and checks the committed
       .qplug carries the same one,
    2. packs the .qplug into feed/<id>.<version>.nupkg (dotnet pack),
    3. adds or replaces that version's entry in feed/index.json, keeping
       every earlier version.
  Commit and push feed/ afterwards; Q-SYS reads it from GitHub raw.

.PARAMETER ReleaseNotes
  Release notes for this version, shown in the Asset Installer. Defaults to
  "Plugin version <version>".
#>
param(
  [string]$ReleaseNotes
)

$ErrorActionPreference = 'Stop'

$PackageId  = 'Zoom-Room-Controls'
$Repo       = 'isaaacporter/q-sys-plugin-zoom-room-controls'
$ProjectUrl = "https://github.com/$Repo"
$RawUrl     = "https://raw.githubusercontent.com/$Repo/main"
$FeedUrl    = "$RawUrl/feed"
$IconUrl    = "$RawUrl/package/icon.png"

$Root    = Split-Path $PSScriptRoot -Parent
$SrcDir  = Join-Path $Root 'src\ZoomRoomControls'
$Qplug   = Join-Path $SrcDir 'ZoomRoomControls.qplug'
$FeedDir = Join-Path $Root 'feed'
$ObjDir  = Join-Path $PSScriptRoot 'obj'
$Utf8    = New-Object Text.UTF8Encoding $false

# -- Version ------------------------------------------------------------------

# BuildVersion, not Version: this plugin's Version is the short "1.0" shown
# on the block, while BuildVersion carries the full release number.
function Get-PluginVersion([string]$Path) {
  $m = Select-String -Path $Path -Pattern '^\s*BuildVersion\s*=\s*"([^"]+)"' | Select-Object -First 1
  if (-not $m) { throw "No BuildVersion = `"...`" line in $Path" }
  $m.Matches[0].Groups[1].Value
}

$PluginVersion = Get-PluginVersion (Join-Path $SrcDir 'info.lua')
$QplugVersion  = Get-PluginVersion $Qplug
if ($PluginVersion -ne $QplugVersion) {
  throw "info.lua is $PluginVersion but the compiled .qplug is $QplugVersion -- rebuild the plugin first."
}

# NuGet normalises 1.0.1.0 to 1.0.1; do the same so file names, the feed
# and the release tags all agree.
$parts = $PluginVersion.Split('.')
if ($parts.Count -eq 4 -and $parts[3] -eq '0') { $parts = $parts[0..2] }
$Version = $parts -join '.'

if (-not $ReleaseNotes) { $ReleaseNotes = "Plugin version $PluginVersion" }

Write-Host "Packing $PackageId $Version (plugin $PluginVersion)"

# -- Pack ---------------------------------------------------------------------

function Escape-Xml([string]$s) { [Security.SecurityElement]::Escape($s) }

New-Item -ItemType Directory -Force $ObjDir, $FeedDir | Out-Null
$nuspec = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ZoomRoomControls.nuspec'))
$tokens = [ordered]@{
  id            = $PackageId
  version       = $Version
  projectUrl    = $ProjectUrl
  iconUrl       = $IconUrl
  pluginVersion = $PluginVersion
  releaseNotes  = $ReleaseNotes
  qplug         = $Qplug
  icon          = Join-Path $PSScriptRoot 'icon.png'
}
foreach ($k in $tokens.Keys) { $nuspec = $nuspec.Replace("`$$k`$", (Escape-Xml $tokens[$k])) }
[IO.File]::WriteAllText((Join-Path $ObjDir 'package.nuspec'), $nuspec, $Utf8)

& dotnet pack (Join-Path $PSScriptRoot 'pack.csproj') -o $FeedDir --nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet pack failed ($LASTEXITCODE)" }

$NupkgName = "$PackageId.$Version.nupkg"
if (-not (Test-Path (Join-Path $FeedDir $NupkgName))) { throw "dotnet pack did not produce $NupkgName" }

# -- Feed ---------------------------------------------------------------------
# Same shape as the registration index a Gitea NuGet registry serves, which
# Q-SYS Library is known to accept: one page, every version inlined.

$IndexPath = Join-Path $FeedDir 'index.json'
$IndexUrl  = "$FeedUrl/index.json"

$entries = @()
if (Test-Path $IndexPath) {
  $old = [IO.File]::ReadAllText($IndexPath) | ConvertFrom-Json
  $entries = @($old.items[0].items | Where-Object { $_.catalogEntry.version -ne $Version })
}

$content = "$FeedUrl/$NupkgName"
$entries += [pscustomobject][ordered]@{
  '@id'          = "$FeedUrl/$Version.json"
  packageContent = $content
  catalogEntry   = [ordered]@{
    '@id'                    = "$FeedUrl/$Version.json"
    authors                  = 'Isaac Porter'
    copyright                = '2026 Isaac Porter'
    dependencyGroups         = @()
    description              = ([xml]$nuspec).package.metadata.description
    iconUrl                  = $IconUrl
    id                       = $PackageId
    isPrerelease             = $false
    language                 = ''
    licenseUrl               = ''
    packageContent           = $content
    projectUrl               = $ProjectUrl
    requireLicenseAcceptance = $false
    summary                  = ([xml]$nuspec).package.metadata.summary
    tags                     = ([xml]$nuspec).package.metadata.tags
    version                  = $Version
    releaseNotes             = $ReleaseNotes
    published                = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  }
}
$entries = @($entries | Sort-Object { [version]$_.catalogEntry.version })

$index = [ordered]@{
  '@id'   = $IndexUrl
  '@type' = @('catalog:CatalogRoot', 'PackageRegistration', 'catalog:Permalink')
  count   = 1
  items   = @(
    [ordered]@{
      '@id' = $IndexUrl
      lower = $entries[0].catalogEntry.version
      upper = $entries[-1].catalogEntry.version
      count = $entries.Count
      items = $entries
    }
  )
}
$json = ($index | ConvertTo-Json -Depth 10) -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText($IndexPath, $json + "`r`n", $Utf8)

Write-Host "Wrote feed\$NupkgName and feed\index.json ($($entries.Count) version(s))"
Write-Host "Personal Package URL: $IndexUrl"
