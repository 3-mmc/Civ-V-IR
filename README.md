# CivVNeo

A personal Civilization V package built on full Vox Populi, with selected community mods, original features, and measured optimizations.

## Foundation

The local upstream source checkout is pinned to Vox Populi **5.4.6**, tag `Release-5.4.6`, commit `dcb33a654cd9e8efb038a0733b4025e19cbcd8ba`.

- [Package blueprint](docs/package-blueprint.md)
- [Current mod shortlist](docs/mod-shortlist.md)
- [Formable Nations design](docs/formable-nations-design.md): first original component, source in `mods/FormableNations/` (`python3 build.py --install` validates, packages and deploys it as `MODS\(9) Formable Nations`)
- [Upstream source lock](upstream.lock.json)
- [Upstream development instructions](upstream/Community-Patch-DLL/DEVELOPMENT.md)
- [Upstream build toolchain](upstream/Community-Patch-DLL/docs/build-toolchain.md)

## Current state

The upstream repository is a shallow, sparse source checkout in `upstream/Community-Patch-DLL`. It includes gameplay C++, SDK dependencies, Lua API annotations, and documentation. Packaged gameplay data, UI, and artwork have not been materialized. Git can fetch those from the same pinned commit when needed.

**Stock VP 5.4.6 (with EUI) was installed on 2026-10-06** into the real Steam game (`E:\SteamLibrary`) and `Documents\My Games\Sid Meier's Civilization 5`. It replays the official installer's "Vox Populi (with EUI)" component by hand, because that installer only detects Civ V under `C:\Program Files`. Files and hashes are in `install-manifest-vp-5.4.6.sha256` (`./docs/` = Documents, `./game/` = game folder). The only stock file overwritten is `Assets\DLC\Expansion2\Expansion2.Civ5Pkg`; the original is in `backups/stock/`. To roll back, restore that file and delete `Assets\DLC\UI_bc1`, `Assets\DLC\VPUI`, `Assets\DLC\Expansion2\Sounds\XML\MinorCivSounds_VoxPopuli.xml`, the five `MODS\(n) …` folders and `Text\VPUI_tips_en_us.xml`. Steam "Verify integrity" would also restore the stock `.Civ5Pkg` and break VP's UI.

No CivVNeo DLL has been compiled and no optional mod has been added. The `Game Files/` copy here is still unmodified.

Full Vox Populi is the selected gameplay foundation. Matching VP/EUI components are the proposed interface baseline. Optional mods remain candidates pending review and testing. Multiplayer and preservation of existing saves are not yet specified; neither is currently promised.

The project is backed up on GitHub as **Civ-V-IR** ("International Relations for Civ V", private: `github.com/3-mmc/Civ-V-IR`) since 2026-10-07. The repository holds the documents, the mod sources and tests, the install manifest and the upstream lock. These are excluded (`.gitignore`):
- `Game Files/`: a local copy of the game.
- `downloads/`: the VP installer and its extracted files.
- `upstream/`: the VP source, a separate Git checkout pinned in `upstream.lock.json`.
- `backups/`: the stock `Expansion2.Civ5Pkg` and the original `config.ini`.

Re-fetch upstream with `git clone --depth 1 --branch Release-5.4.6 https://github.com/LoneGazebo/Community-Patch-DLL upstream/Community-Patch-DLL`. The mod's offline column check reads the DLL sources from there.
