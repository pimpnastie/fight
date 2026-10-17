<#
  Switch SF6 between MODDED (offline) and ONLINE (clean), then launch it.

  Modded: enables REFramework (dinput8.dll) and blocks StreetFighter6.exe in Windows Firewall,
          so a modded game can't reach Capcom's servers at all.
  Online: disables REFramework (renames dinput8.dll -> dinput8.dll.off) and removes the block,
          so the game runs exactly like an unmodded install.

  Run: powershell -ExecutionPolicy Bypass -File mode.ps1 -Mode Modded|Online|Status [-GamePath "..."] [-NoLaunch]
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet("Modded", "Online", "Status")][string]$Mode,
    [string]$GamePath,
    [switch]$NoLaunch
)
$ErrorActionPreference = "Stop"
$RULE = "SF6 Scorpion Moveset - offline block"
$APPID = "1364780"
function Say($m, $c = "Cyan") { Write-Host "[Scorpion] $m" -ForegroundColor $c }
function Fail($m) { Say $m "Red"; throw $m }

function Find-SF6 {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }
    $steam = $steam -replace "/", "\"
    $libs = @($steam)
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace "\\\\", "\") } }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $manifest = Join-Path $lib "steamapps\appmanifest_$APPID.acf"
        if (Test-Path $manifest) {
            $dir = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
            $p = Join-Path $lib "steamapps\common\$dir"
            if (Test-Path (Join-Path $p "StreetFighter6.exe")) { return $p }
        }
    }
    return $null
}

function Is-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Firewall changes need admin: run just those commands elevated (one UAC prompt)
function Set-Firewall($block, $exe) {
    $cmd = if ($block) {
        "Remove-NetFirewallRule -DisplayName '$RULE' -ErrorAction SilentlyContinue; " +
        "New-NetFirewallRule -DisplayName '$RULE' -Direction Outbound -Program '$exe' -Action Block | Out-Null; " +
        "New-NetFirewallRule -DisplayName '$RULE' -Direction Inbound  -Program '$exe' -Action Block | Out-Null"
    } else {
        "Remove-NetFirewallRule -DisplayName '$RULE' -ErrorAction SilentlyContinue"
    }
    try {
        if (Is-Admin) { Invoke-Expression $cmd }
        else { Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -Command $cmd" }
        return $true
    } catch { return $false }
}

function Fw-Blocked { [bool](Get-NetFirewallRule -DisplayName $RULE -ErrorAction SilentlyContinue) }

if (-not $GamePath) { $GamePath = Find-SF6 }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath "StreetFighter6.exe"))) { Fail "Couldn't find Street Fighter 6. Use -GamePath." }
$exe = Join-Path $GamePath "StreetFighter6.exe"
$on  = Join-Path $GamePath "dinput8.dll"
$off = Join-Path $GamePath "dinput8.dll.off"

if ($Mode -eq "Status") {
    $mods = if (Test-Path $on) { "ON" } elseif (Test-Path $off) { "OFF" } else { "not installed" }
    Say "REFramework/mods: $mods"
    Say ("Firewall block: " + $(if (Fw-Blocked) { "ON (game offline)" } else { "OFF" }))
    return
}

if (Get-Process -Name "StreetFighter6" -ErrorAction SilentlyContinue) { Fail "Close Street Fighter 6 first." }

if ($Mode -eq "Modded") {
    if (Test-Path $off) { Move-Item $off $on -Force }
    if (-not (Test-Path $on)) { Fail "REFramework isn't installed. Run install.bat first." }
    if (Set-Firewall $true $exe) { Say "SF6 blocked from the internet while modded." "Green" }
    else { Say "Firewall block skipped (admin prompt declined). Lua still won't run online, but stay offline anyway." "Yellow" }
    Say "MODDED mode: mods ON. Use Training Mode only." "Green"
}
else {
    if (Test-Path $on) {
        if (Test-Path $off) { Remove-Item $off -Force }
        Move-Item $on $off -Force
    }
    if (Set-Firewall $false $exe) { Say "Firewall block removed." "Green" }
    else { Say "Couldn't remove the firewall block (admin prompt declined). The game may not connect until you allow it." "Yellow" }
    Say "ONLINE mode: mods OFF, game is clean." "Green"
}

if (-not $NoLaunch) { Start-Process "steam://rungameid/$APPID" }
