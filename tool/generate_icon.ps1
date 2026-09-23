<#
.SYNOPSIS
    Regenerates every launcher asset from design/icon/undercover_icon.svg.

.DESCRIPTION
    The SVG is the only source of the icon's geometry; this script is just the
    press. It renders three artboards of that file with Inkscape:

        0:0:1024:1024        the full icon      -> legacy mipmaps + store PNG
        1216:0:2240:1024     adaptive foreground -> ic_launcher_foreground.png
        2432:0:3456:1024     themed monochrome   -> ic_launcher_monochrome.png

    The adaptive background is a colour resource, not an image, so nothing is
    rendered for it.

    Run from the repository root:
        powershell -ExecutionPolicy Bypass -File tool/generate_icon.ps1
#>

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$svg = Join-Path $repo 'design/icon/undercover_icon.svg'
$res = Join-Path $repo 'android/app/src/main/res'

function Find-Inkscape {
    # The installer does not put Inkscape on PATH, so look where it actually
    # lands before falling back to PATH and the registry.
    $candidates = @(
        "$env:ProgramFiles\Inkscape\bin\inkscape.exe",
        "$env:ProgramFiles\Inkscape\inkscape.exe",
        "${env:ProgramFiles(x86)}\Inkscape\bin\inkscape.exe",
        "$env:LOCALAPPDATA\Programs\Inkscape\bin\inkscape.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

    $onPath = Get-Command inkscape.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\inkscape.exe'
    if (Test-Path $key) {
        $fromReg = (Get-ItemProperty $key).'(default)'
        if ($fromReg -and (Test-Path $fromReg)) { return $fromReg }
    }
    throw "Inkscape not found. Install it, or add inkscape.exe to PATH."
}

function Export-Artboard {
    param(
        [Parameter(Mandatory)][string]$Area,
        [Parameter(Mandatory)][int]$Size,
        [Parameter(Mandatory)][string]$Out
    )
    $dir = Split-Path -Parent $Out
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path $Out) { Remove-Item $Out -Force }

    & $inkscape $svg `
        --export-type=png `
        --export-filename=$Out `
        --export-area=$Area `
        --export-width=$Size `
        --export-height=$Size | Out-Null

    if (-not (Test-Path $Out)) {
        throw "Inkscape produced nothing for $Out (area $Area, ${Size}px)"
    }
    $bytes = (Get-Item $Out).Length
    if ($bytes -lt 200) { throw "$Out is only $bytes bytes - the export failed" }
    "  {0,-58} {1,4}px  {2,7:N0} B" -f (Resolve-Path -Relative $Out), $Size, $bytes
}

if (-not (Test-Path $svg)) { throw "Missing source: $svg" }
$inkscape = Find-Inkscape
$version = (& $inkscape --version 2>$null | Select-Object -First 1)
"Inkscape: $version"
"Source:   design/icon/undercover_icon.svg"
""

$AREA_ICON = '0:0:1024:1024'
$AREA_FG = '1216:0:2240:1024'
$AREA_MONO = '2432:0:3456:1024'

# Legacy tile per density, and the store asset.
$legacy = [ordered]@{ 'mipmap-mdpi' = 48; 'mipmap-hdpi' = 72; 'mipmap-xhdpi' = 96
                      'mipmap-xxhdpi' = 144; 'mipmap-xxxhdpi' = 192 }
# Adaptive layers are always 108dp square.
$adaptive = [ordered]@{ 'mipmap-mdpi' = 108; 'mipmap-hdpi' = 162; 'mipmap-xhdpi' = 216
                        'mipmap-xxhdpi' = 324; 'mipmap-xxxhdpi' = 432 }

'Legacy launcher tiles'
foreach ($d in $legacy.Keys) {
    Export-Artboard -Area $AREA_ICON -Size $legacy[$d] -Out (Join-Path $res "$d/ic_launcher.png")
}
Export-Artboard -Area $AREA_ICON -Size 512 `
    -Out (Join-Path $repo 'android/app/src/main/ic_launcher-playstore.png')

''
'Adaptive foreground'
foreach ($d in $adaptive.Keys) {
    Export-Artboard -Area $AREA_FG -Size $adaptive[$d] -Out (Join-Path $res "$d/ic_launcher_foreground.png")
}

''
'Adaptive monochrome'
foreach ($d in $adaptive.Keys) {
    Export-Artboard -Area $AREA_MONO -Size $adaptive[$d] -Out (Join-Path $res "$d/ic_launcher_monochrome.png")
}

''
'Done.'
