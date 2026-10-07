# Personal package blueprint

## Intended result

One reproducible personal installation built on full Vox Populi, with a deliberately selected set of interoperable additions. Preserve the ability to import upstream fixes while developing original features and performance improvements.

The unit of compatibility is an exact combination of versions, configuration, and load order. A mod's reputation or a successful launch is not evidence that a complete campaign will work.

## Composition

| Layer | Responsibility | Integration approach |
| --- | --- | --- |
| Pinned Vox Populi | Gameplay rules, AI, database extensions, engine interface | Start with an unchanged release as the reference build. |
| Matching VP UI | EUI and the compatibility components intended for that VP release | Treat as a coordinated set; review every overlapping UI replacement. |
| Selected mods | Additional content and focused improvements | Retain original identity, version, authorship, dependencies, and source location. |
| CivVNeo integration | Resolve overlapping rules, SQL, Lua, UI, and content | Keep explicit patches and record the reason for each. |
| Original features | User's own mechanics and optimization work | Prefer existing data/Lua extension points; change C++ when required. |
| Optional companion | Isolated expensive calculations and external tools | Introduce only after a stable baseline and measured need. |

One installed package can retain modular sources and multiple internal mod components. Flattening everything into one undifferentiated source tree would make upstream updates and diagnosis harder.

The normal Civ V mod-loading route supports one replacement gamecore DLL. Features from competing gamecore DLLs require source-level integration and rebuilding that one DLL, not simultaneous installation. This restriction does not forbid unrelated helper libraries or an external process. The community [compatibility thread](https://forums.civfanatics.com/threads/mods-compatible-with-vox-populi-vp.542679/) records the gamecore limitation; its individual mod compatibility claims are historical and must be rechecked.

## Upstream strategy

Use `Release-5.4.6` as the initial reference, pinned by the full commit in `../upstream.lock.json`. It is listed as a stable release in the [release announcement](https://forums.civfanatics.com/threads/new-stable-version-%E2%80%93-5-4-6-august-31-2026.703984/).

Before code changes, create a development branch from that commit. Keep individual feature and integration changes reviewable. Test upstream upgrades separately and promote them deliberately; preserve the previous complete package for campaigns that need it. The reference checkout currently remains unchanged.

Use the build process documented at the pinned revision. The supplied project has legacy ABI dependencies; a newer IDE does not remove them. Upstream also documents Clang build routes. Local toolchain availability has not been audited or provisioned.

## Admission record for each mod

Record the exact version or commit, original download URL, archive hash, author and license, required VP version, dependencies, load relationships, replaced files, and database objects changed. Record whether its functionality is already supplied by VP. Keep author-reported compatibility separate from locally verified compatibility.

Check these conflict types:

- Competing replacement gamecore DLLs.
- Lua/XML files replacing the same UI contexts or virtual filesystem paths.
- SQL modifying the same rows, deleting another mod's records, or referencing renamed types.
- Duplicate event handlers or duplicate gameplay effects.
- Art and unit-definition pressure, including strategic-view behavior.
- New mechanics that the AI cannot use or value correctly.
- Save serialization changes and gameplay state that fails to survive reload.

Declared dependencies and references help ordering; they do not merge conflicting files or reconcile incompatible rules. Do not use numeric folder prefixes as the compatibility mechanism.

## Validation and packaging

1. Establish unchanged VP with matching UI in a test installation and record the full configuration.
2. Add one candidate or tightly coupled dependency group at a time. Compare database and Lua logs with the baseline, and inspect affected in-game behavior.
3. Exercise relevant systems: diplomacy, city screens, combat, events, era progression, normal and strategic views, and save/load. Run representative AI autoplay sessions for broader regressions.
4. Measure turn times and process memory on repeatable scenarios before claiming an optimization. Keep hardware, game settings, and logging conditions consistent.
5. Generate an installable package only from an explicit manifest, with hashes, resolved load relationships, and a list of deployed files. Rollback should restore files the package replaced and remove only files it owns.
6. If multiplayer becomes a requirement, add synchronization and multiplayer packaging checks before calling a release multiplayer-compatible. Treat new campaigns as the first test target; do not infer existing-save compatibility.

VP includes modpack tooling in its upstream tree. Evaluate that against the selected release before inventing a separate pack format. During development, regular mod components are easier to inspect; the final installation can be generated from them.

## Optimization direction

Profile current VP before reimplementing improvements it already contains. Prefer removing repeated work, reducing allocations, and improving invalidation of cached calculations. Require behavior-equivalence checks for changes presented as optimizations rather than gameplay changes.

A future companion should consume bounded snapshots and return versioned results. The gamecore remains responsible for validating and applying decisions. Large working sets should remain external. Persistent companion state needs coordinated saving; deterministic behavior and result synchronization need explicit design if multiplayer is required.
