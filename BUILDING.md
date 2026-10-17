# Scorpion → Ryu Kit (SF6) — educational demo

MK1 Scorpion's look on Ryu, with an MK-style move list built from SF6's own animations. Offline / training mode only.

## Contents
| Path | What |
|---|---|
| `Scorpion Moveset/` | MMDK addon (Fluffy Mod Manager–ready) |
| `blender/mk1_to_sf6_refit.py` | Fits the MK1 mesh onto Ryu's skeleton |

## Move list (v1.2)
| Move | Input | Gameplay from | Animation / VFX borrowed from |
|---|---|---|---|
| Spear | B,F + P (PP = EX) | Ryu's Hadoken: hit = 40f stagger + pull | **Ed**'s chain-grab arm throw (`SP_01_PsychoAnchor`, has chain + lock keys) |
| Takedown | B,F + K (KK = EX) | Ryu's Donkey Kick: knockdown | Ryu (already a lunging kick) |
| Teleport | D,B + HP | **Akuma**'s Ashura Senku (full 6-action chain) | Akuma; falls back to Ryu's dash ×3 if Akuma's bank won't load |
| Hellfire Uppercut | F,D,DF + HP / PP | Ryu's Shoryuken | **Ken**'s flame VFX keys by default; swappable to **Mai** (see below) |

Ryu's normals, Tatsu, Hashogeki and supers stay. Every borrowed piece has a toggle in the MMDK menu and the `cfg` table.

## Upgrades (v1.2)
- **Use the [yulgi MMDK fork](https://github.com/yulgi/MMDK)** instead of stock MMDK. Same API, but its `tables.lua` knows the newer fighters (Sagat, Mai, Elena, C. Viper, Alex, Ingrid, Yasmine) and it adds `MMDK_BatchDump.lua`, which loads each fighter in Training Mode and dumps their data in one run. Stock MMDK 1.0.8 stops at Terry.
- **Better flame donor: Mai.** Her fire moves are a closer match to Hellfire than Ken's. After batch-dumping, open `reframework/data/MMDK/PlayerData/Mai/Mai Names.json`, find her fiery rising/spin move IDs, and set `hellfire_donor = { char = "Mai", h = <id>, ex = <id> }` in the Lua.
- **Spear voice line.** No fighter says "Get over here", but you can pick the closest shout: preview voices in MMDK's Moveset Research window, then set `spear_voice_id` to that SoundID.
- **Model install without repacking.** Recent REFramework nightlies (Nexus mod 73) add a LooseFileLoader, so unpacked files under the game's `natives/` folder can load directly. For the Scorpion mesh this means you can drop REME's exported `.mesh`/`.mdf2`/`.tex` at Ryu's paths and test without building a pak; use Fluffy once it looks right.
- Reminder from REFramework: Lua scripting is disabled in online matches, so this moveset is offline-only by design.

## 1. Install the moveset
1. REFramework nightly `SF6.zip` → put `dinput8.dll` in the SF6 folder.
2. MMDK: https://github.com/yulgi/MMDK (fork with newer fighters) or https://github.com/alphazolam/MMDK → install the `MMDK` folder (Fluffy Mod Manager or copy into the game folder).
3. Install `Scorpion Moveset/` the same way. The Lua lands at `reframework/autorun/MMDK/Ryu/Scorpion Moveset.lua`.
4. In game: **Insert** → Script Generated UI → MMDK → enable Ryu + "Scorpion Moveset". Start a training match as Ryu.

Tuning: edit the `cfg` table at the top of the Lua (damage, stagger, pull, teleport distance/button), then reset scripts in REFramework. Use MMDK's **Moveset Research** window + EMV Engine to watch keys frame by frame.

## 2. Make him look like Scorpion
1. **MK1 extract** — FModel (needs current MK1 AES key + mappings from the MK1 modding community). Export Scorpion's skeletal mesh as `.psk` + textures as `.png`.
2. **SF6 extract** — REE.PAK.Tool → find Ryu's body mesh + mdf2 (Ryu is `esf001`).
3. **Blender 4.x** — import Ryu with REME (RE Mesh Editor), import Scorpion with the PSK/PSA addon.
4. **Refit** — open `blender/mk1_to_sf6_refit.py` in the Scripting tab, set `SRC_MESH`, `REF_MESH`, `TARGET_ARM`, Run. Pose the armature to check bends (shoulders, hips, wrists); touch up weights by hand.
5. **Materials** — rename Scorpion's material slots to Ryu's mdf2 material names (REME exports by name), convert textures to `.tex` with REME/RE Toolbox, point the mdf2 at them.
6. **Export** with REME to Ryu's mesh path, package with the same folder structure, install via Fluffy. Pick that Ryu costume slot in game.

## What's approximate (be honest about the demo)
- **Animations are SF6's**, mixed from Ryu, Ed, Akuma and Ken. MK1 animations don't transfer (different engine/skeleton/frame data); there's no public MK→RE motion converter.
- **How borrowing works:** the mod loads the donor's `.motlist` into Ryu with `add_dynamic_motionbank`, using the donor's own bank ID so their MotionKeys resolve. Paths are built from the bank ID (e.g. bank `1900601` → `esf019v00_SpecialSkill_01.motlist`). That pattern is verified for Ryu; for other fighters it's inferred. MMDK checks the file exists first, so a wrong path just prints `[Scorpion] could not load ...` in the REFramework console and that piece falls back.
- **Spear:** Ed's animation is ~98 frames vs Hadoken's 112, and the projectile still spawns on Hadoken's frame 15. If the arm throw and the projectile don't line up, change `spear_anim_id` or move the ShotKey start frame in Moveset Research. Pull direction (`spear_pull_x`) is untested; set 0 if it pushes away.
- **Teleport:** Akuma's hurtbox/pushbox rect IDs don't exist on Ryu, so the whole Ashura is invincible and passes through. Fair for a demo, too strong for real play.
- **Flame VFX (Ken) and Akuma's teleport effect** reference those fighters' effect containers. They show only if that container is loaded in the match. If not (e.g. no Ken on screen), grab the `.efx` path in EMV Engine and load it with `clone_vfx` + `setResources` (see MMDK README "Adding a VfxKey").
- **Still missing:** the spear's rope and "Get over here" — no SF6 fighter has a matching rope projectile or voice line; that needs custom VFX/audio banks.
- **IDs used:** actions 1075–1080 (Akuma clone) and 1302 (dash fallback), HIT_DT 4100+, command lists 50–51 — all free for Ryu as of MMDK's dumps. If a game patch changes Ryu's data, re-dump in MMDK and re-check.
- Ripped assets are for personal use only; don't redistribute the Scorpion mesh.
