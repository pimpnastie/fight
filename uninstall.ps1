<#
  Removes the Scorpion Moveset. Add -All to also remove MMDK and REFramework
  (restores dinput8.dll.bak if the installer made one).
  Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GamePath "..."] [-All]
#>
param([string]$GamePath, [switch]$All)
$ErrorActionPreference = "Stop"
function Say($m, $c = "Cyan") { Write-Host "[Scorpion] $m" -ForegroundColor $c }

if (-not $GamePath) {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath -replace "/", "\"
    $libs = @($steam)
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace "\\\\", "\") } }
    foreach ($lib in $libs) {
        $p = Join-Path $lib "steamapps\common\Street Fighter 6"
        if (Test-Path (Join-Path $p "StreetFighter6.exe")) { $GamePath = $p; break }
    }
}
if (-not $GamePath) { Say "Couldn't find SF6. Use -GamePath." "Red"; exit 1 }

$lua = Join-Path $GamePath "reframework\autorun\MMDK\Ryu\Scorpion Moveset.lua"
if (Test-Path $lua) { Remove-Item $lua -Force; Say "Removed Scorpion Moveset." "Green" } else { Say "Scorpion Moveset not found." "Yellow" }

if ($All) {
    $mmdk = Join-Path $GamePath "reframework\autorun"
    Remove-Item (Join-Path $mmdk "MMDK.lua"), (Join-Path $mmdk "MMDK") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $GamePath "reframework\data\MMDK") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $GamePath "dinput8.dll.off") -Force -ErrorAction SilentlyContinue
    try { Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -Command Remove-NetFirewallRule -DisplayName 'SF6 Scorpion Moveset - offline block' -ErrorAction SilentlyContinue"; Say "Removed firewall block." "Green" } catch { Say "Firewall rule not removed (admin declined)." "Yellow" }
    $dll = Join-Path $GamePath "dinput8.dll"
    if (Test-Path "$dll.bak") { Move-Item "$dll.bak" $dll -Force; Say "Restored original dinput8.dll." "Green" }
    elseif (Test-Path $dll) { Remove-Item $dll -Force; Say "Removed REFramework." "Green" }
}
