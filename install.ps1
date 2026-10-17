<#
  SF6 Scorpion Moveset installer
  - Finds Street Fighter 6 (Steam), or use -GamePath "D:\...\Street Fighter 6"
  - Installs REFramework (SF6 nightly), MMDK, and the Scorpion Moveset
  - Backs up an existing dinput8.dll before replacing it
  Run:  powershell -ExecutionPolicy Bypass -File install.ps1
  Or:   irm https://raw.githubusercontent.com/<OWNER>/sf6-scorpion-moveset/main/install.ps1 | iex
#>
param(
    [string]$GamePath,
    [switch]$SkipREFramework,
    [switch]$SkipMMDK,
    [string]$MMDKRepo = "yulgi/MMDK",                       # fork with newer fighters; or alphazolam/MMDK
    [string]$ModRepo  = "<OWNER>/sf6-scorpion-moveset",     # used when run via irm | iex
    [string]$ModBranch = "main"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$REF_URL = "https://github.com/praydog/REFramework-nightly/releases/download/latest/SF6.zip"
$SF6_APPID = "1364780"

function Say($msg, $color = "Cyan") { Write-Host "[Scorpion] $msg" -ForegroundColor $color }
function Fail($msg) { Say $msg "Red"; throw $msg }   # throw, not exit: exit would close the window under irm | iex

# Merge a folder's contents into a destination (Copy-Item can nest folders when the destination exists)
function Merge-Dir($src, $dst) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Fail "Copy failed ($src -> $dst), robocopy code $LASTEXITCODE" }
    $global:LASTEXITCODE = 0
}

function Find-SF6 {
    $steam = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath }
    if (-not $steam) { return $null }
    $steam = $steam -replace "/", "\"
    $libs = @($steam)
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
            $libs += ($m.Groups[1].Value -replace "\\\\", "\")
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $manifest = Join-Path $lib "steamapps\appmanifest_$SF6_APPID.acf"
        if (Test-Path $manifest) {
            $dir = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
            $p = Join-Path $lib "steamapps\common\$dir"
            if (Test-Path (Join-Path $p "StreetFighter6.exe")) { return $p }
        }
    }
    return $null
}

function Get-Zip($url, $name) {
    $tmp = Join-Path $env:TEMP ("sf6scorpion_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp "$name.zip"
    Say "Downloading $name..."
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp "x") -Force
    return (Join-Path $tmp "x")
}

# 1. Locate the game
if (-not $GamePath) { $GamePath = Find-SF6 }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath "StreetFighter6.exe"))) {
    Fail "Couldn't find Street Fighter 6. Re-run with:  -GamePath 'X:\path\to\Street Fighter 6'"
}
Say "Game folder: $GamePath" "Green"

if (Get-Process -Name "StreetFighter6" -ErrorAction SilentlyContinue) {
    Fail "Close Street Fighter 6 first, then run this again."
}

$refDir = Join-Path $GamePath "reframework"

# 2. REFramework
if (-not $SkipREFramework) {
    $x = Get-Zip $REF_URL "REFramework"
    $dll = Get-ChildItem -Path $x -Recurse -Filter "dinput8.dll" | Select-Object -First 1
    if (-not $dll) { Fail "dinput8.dll not found in REFramework download." }
    $target = Join-Path $GamePath "dinput8.dll"
    if ((Test-Path $target) -and -not (Test-Path "$target.bak")) {
        Copy-Item $target "$target.bak"
        Say "Backed up existing dinput8.dll -> dinput8.dll.bak" "Yellow"
    }
    Copy-Item $dll.FullName $target -Force
    Say "REFramework installed." "Green"
}

# 3. MMDK (only the reframework/ folder of its MMDK package)
if (-not $SkipMMDK) {
    $x = Get-Zip "https://github.com/$MMDKRepo/archive/refs/heads/main.zip" "MMDK"
    $src = Get-ChildItem -Path $x -Recurse -Directory -Filter "reframework" |
           Where-Object { Test-Path (Join-Path $_.FullName "autorun\MMDK.lua") } | Select-Object -First 1
    if (-not $src) { Fail "MMDK layout not recognized in $MMDKRepo." }
    Merge-Dir $src.FullName $refDir
    Say "MMDK installed from $MMDKRepo." "Green"
}

# 4. Scorpion Moveset (from this folder, or downloaded when run via irm | iex)
$here = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
$modSrc = if ($here) { Join-Path $here "mod\Scorpion Moveset\reframework" } else { $null }
if (-not $modSrc -or -not (Test-Path $modSrc)) {
    if ($ModRepo -like "*<OWNER>*") { Fail "Set -ModRepo owner/repo (or run from a downloaded copy)." }
    $x = Get-Zip "https://github.com/$ModRepo/archive/refs/heads/$ModBranch.zip" "ScorpionMoveset"
    $modSrc = Get-ChildItem -Path $x -Recurse -Directory -Filter "reframework" |
              Where-Object { $_.FullName -like "*Scorpion Moveset*" } | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $modSrc) { Fail "Couldn't find the moveset files in the download." }
Merge-Dir $modSrc $refDir
Say "Scorpion Moveset installed." "Green"

# 5. Leave mods OFF by default: the game stays clean until "Play Modded (offline).bat" turns them on
$on = Join-Path $GamePath "dinput8.dll"; $off = "$on.off"
if (Test-Path $on) { if (Test-Path $off) { Remove-Item $off -Force }; Move-Item $on $off -Force }

Write-Host ""
Say "Installed. Mods are OFF right now, so the game is clean for online play." "Green"
Say "To use the moveset: run 'Play Modded (offline).bat' (turns mods on + blocks SF6's internet), then Training Mode as Ryu -> Insert -> Script Generated UI -> MMDK -> enable Ryu + 'Scorpion Moveset'." "Green"
Say "Before playing online again: run 'Play Online (clean).bat'." "Yellow"
