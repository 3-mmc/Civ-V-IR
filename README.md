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

Formable Nations' `build.py --install` also writes first-contact sound entries for its 24 added City-States into the game's `Assets\DLC\Expansion2\Sounds\XML\MinorCivSounds_VoxPopuli.xml`, between marker comments. That file therefore no longer matches `install-manifest-vp-5.4.6.sha256`; VP's original is in `backups/vp/`. No CivVNeo DLL has been compiled and no optional mod has been added. The `Game Files/` copy here is still unmodified.

Full Vox Populi is the selected gameplay foundation. Matching VP/EUI components are the proposed interface baseline. Optional mods remain candidates pending review and testing. Multiplayer and preservation of existing saves are not yet specified; neither is currently promised.

The project is backed up on GitHub as **Civ-V-IR** ("International Relations for Civ V", private: `github.com/3-mmc/Civ-V-IR`) since 2026-10-07. The repository holds the documents, the mod sources and tests, the install manifest and the upstream lock. These are excluded (`.gitignore`):
- `Game Files/`: a local copy of the game.
- `downloads/`: the VP installer and its extracted files.
- `upstream/`: the VP source, a separate Git checkout pinned in `upstream.lock.json`.
- `backups/`: the stock `Expansion2.Civ5Pkg` and the original `config.ini`.

Re-fetch upstream with `git clone --depth 1 --branch Release-5.4.6 https://github.com/LoneGazebo/Community-Patch-DLL upstream/Community-Patch-DLL`. The mod's offline column check reads the DLL sources from there.

## Engine builds (toolchain B, portable)

VP's gamecore DLL is built with the clang route VP's CI uses, set up on 2026-10-07 without any installer or admin rights. Everything lives in `D:\Toolchains` (about 1 GB):
- `SDK70\`: the Windows SDK 7.0 headers and libraries, plus the VC9 headers and libraries. They come from the SDK 7.0 SP1 ISO (`GRMSDK_EN_DVD.iso`, archive.org copy of Microsoft's download). `WinSDK_x86.msi`, `WinSDKBuild_x86.msi` and `vc_stdx86.msi` were extracted with `msiexec /a … TARGETDIR=D:\Toolchains\SDK70`; VC9 lands in `Program Files\Microsoft Visual Studio 9.0\Vc7`.
- `LLVM-20.1.8\`: `clang-cl`, `lld-link`, `llvm-lib`, `llvm-rc` and `lib\clang\20`, taken from the LLVM 20.1.8 Windows archive. LLVM 20 is close to what VP's CI uses; 23.x is untested with VP's C++03 code.
- `Python312\`: the embeddable Windows Python 3.12.10.
- `downloads\`: the original ISO and archives.

Verified on 2026-10-07: unmodified VP 5.4.6 builds in about 3.5 minutes (compile 52 s, LTO link 165 s) into a 17.4 MB 32-bit `CvGameCore_Expansion2.dll` with the same single export as the shipped 17.0 MB DLL. It has not been installed: the shipped DLL stays until an engine change needs testing. The wrapper pins `-fms-compatibility-version=15.00.30729` (VC9). VP's CI gets the same result by letting clang detect VC9's `cl.exe`, which clang only recognises in a `...\VC\bin` directory; the `msiexec /a` layout is `Vc7\bin`. Without the pin the link fails on `__Init_thread_*`, sized `operator delete` and `___std_terminate`.

Build from Windows with `D:\Toolchains\Python312\python.exe tools\build_dll.py --config release --version <text>`. The wrapper runs upstream's `build_vp_clang_sdk.py` with its `C:\Program Files` paths redirected, and writes `commit_id.inc` itself, because Windows git may refuse a checkout made from WSL. The output goes to `upstream\Community-Patch-DLL\clang-output\Release\CvGameCore_Expansion2.dll`.
