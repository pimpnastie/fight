# SF6 Scorpion Moveset

Turns Ryu into an MK-style Scorpion in Street Fighter 6 (PC/Steam), using animations borrowed from other SF6 fighters. Offline and Training Mode only.

| Move | Input | Borrowed from |
|---|---|---|
| Spear (stagger + pull) | ← → + P | Ryu's Hadoken logic, Ed's chain-grab animation |
| Takedown | ← → + K | Ryu's Donkey Kick |
| Teleport | ↓ ← + HP | Akuma's Ashura Senku (falls back to a long invincible dash) |
| Hellfire Uppercut | → ↓ ↘ + HP / PP | Ryu's Shoryuken, Ken's flame effects |

## Install (Windows)

**Option A: download and double-click**
1. Close Street Fighter 6.
2. Code → Download ZIP, extract it anywhere.
3. Double-click `install.bat`.

**Option B: one PowerShell command**
```powershell
irm https://raw.githubusercontent.com/<OWNER>/sf6-scorpion-moveset/main/install.ps1 | iex
```

The installer finds SF6 through Steam, then installs:
- [REFramework](https://github.com/praydog/REFramework) (SF6 nightly), backing up any existing `dinput8.dll`
- [MMDK](https://github.com/yulgi/MMDK), the moveset mod kit
- this moveset

If SF6 isn't found: `install.bat "D:\SteamLibrary\steamapps\common\Street Fighter 6"`

Already have REFramework or MMDK? Add `-SkipREFramework` or `-SkipMMDK` when running `install.ps1`.

## Use it
Mods are **off** after installing, so the game stays clean. Switch with the two launchers in this folder:

| Launcher | Mods | Internet for SF6 | Use for |
|---|---|---|---|
| `Play Modded (offline).bat` | ON | **Blocked** (Windows Firewall) | The Scorpion moveset, Training Mode |
| `Play Online (clean).bat` | OFF (REFramework renamed to `dinput8.dll.off`) | Normal | Ranked, Battle Hub, casuals |

Each launcher asks for admin once (for the firewall rule), then starts SF6 through Steam.

In modded mode: Training Mode → pick **Ryu** → press **Insert** → Script Generated UI → **MMDK** → enable Ryu and **Scorpion Moveset**. Each borrowed piece has its own checkbox. Changes apply next match.

Check the current state any time:
```powershell
powershell -ExecutionPolicy Bypass -File mode.ps1 -Mode Status
```

## Ban safety
Three independent layers keep this out of online play:
1. **REFramework** disables Lua scripts in online matches.
2. **The moveset itself** only applies in Training Mode; anywhere else it does nothing (`training_only = true` in the Lua).
3. **The launchers** turn REFramework off completely for online play, and block SF6's internet while modded.

The rule that matters: **always launch with `Play Online (clean).bat` before going online.** Capcom's terms don't allow modifying the game, and no setup can promise zero risk; layer 3 means the online game isn't modded at all.

## Uninstall
```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1        # just the moveset
powershell -ExecutionPolicy Bypass -File uninstall.ps1 -All   # also MMDK + REFramework
```

## Notes
- A game update can break REFramework until its nightly catches up. Re-run the installer to grab the newest build.
- The Scorpion **look** (MK1 model swap) isn't included and never will be in this repo: it's ripped game content. See [docs/BUILDING.md](docs/BUILDING.md) to make it yourself from your own copies of MK1 and SF6.

## Credits
REFramework by praydog and cursey · MMDK by alphazolam (fork by yulgi) · moveset by Pimpnastie. Fan project, not affiliated with Capcom, NetherRealm or Warner Bros.

## For the maintainer
- Tag a release (`git tag v1.2 && git push --tags`) and GitHub Actions attaches two zips: a Fluffy Mod Manager package and the installer bundle.
- After creating the repo, replace `<OWNER>` in `README.md` and `install.ps1` with your GitHub username.
