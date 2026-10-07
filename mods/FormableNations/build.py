#!/usr/bin/env python3
"""Validate, package and (with --install) deploy the Formable Nations mod.

Packaging writes build/(9) Formable Nations/: sources, a generated .modinfo with MD5s, and
UI/Highlights.xml = the installed VP VPUI Highlights.xml + Overlays/FN_Styles.xml (the game loads
only one Highlights.xml, so ours must carry VP's styles too; rebuild after every VP update).
"""
import argparse
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOD_NAME = "(9) Formable Nations"
MOD_ID = "f0a7c1e2-5b3d-4c8e-9a61-3d2b7e4f9c10"
MOD_VERSION = 1
GAME = Path("/mnt/e/SteamLibrary/steamapps/common/Sid Meier's Civilization V")
USER = Path("/mnt/c/Users/aaron/Documents/My Games/Sid Meier's Civilization 5")
VP_HIGHLIGHTS = GAME / "Assets/DLC/VPUI/Core/Highlights.xml"

SQL = ["SQL/FN_Settings.sql", "SQL/FN_Schema.sql", "SQL/FN_Data.sql", "SQL/FN_Nations.sql", "SQL/FN_Organisations.sql", "SQL/FN_Alliances.sql",
       "SQL/FN_Independence.sql", "SQL/FN_Perks.sql"]
TEXT = ["Text/FN_Text_en_US.xml", "Text/FN_Text_de_DE.xml"]
UI = ["UI/FormableNations.xml", "UI/FormableNations.lua", "UI/FN_Core.lua", "UI/FN_Cohesion.lua", "UI/FN_Organisations.lua",
      "UI/FN_Independence.lua", "UI/FN_Setup.lua", "UI/FN_Alliances.lua"]


def check_lua():
    for f in UI:
        if f.endswith(".lua"):
            subprocess.run(["luac5.1", "-p", str(HERE / f)], check=True)


def check_xml(paths):
    subprocess.run(["xmllint", "--noout", *[str(HERE / p) for p in paths]], check=True)


def check_sql():
    """Run the mod's SQL on the stub database (tests/stub.py): base-game and VP names, and Policies/Units tables with
    exactly the columns VP's DLL reads. Then check references between the mod's own rows and to base names."""
    sys.path.insert(0, str(HERE / "tests"))
    from stub import build_stub
    db = build_stub()
    for f in SQL:
        try:
            db.executescript((HERE / f).read_text(encoding="utf-8"))
        except Exception as e:
            sys.exit(f"{f}: {e}")
    # Every referenced type must at least be well-formed and resolvable within the mod's own rows.
    bad = db.execute("""SELECT c.FormableType FROM FormableNation_Claims c
        LEFT JOIN FormableNations f ON f.Type = c.FormableType WHERE f.Type IS NULL
        UNION SELECT g.FormableType FROM FormableNation_ClaimGroups g
        LEFT JOIN FormableNations f ON f.Type = g.FormableType WHERE f.Type IS NULL
        UNION SELECT f.Type FROM FormableNations f LEFT JOIN Policies p ON p.Type = f.PolicyType WHERE p.Type IS NULL
        UNION SELECT c.FormableType FROM FormableNation_Claims c LEFT JOIN FormableNation_ClaimGroups g
            ON g.FormableType = c.FormableType AND g.GroupID = c.GroupID WHERE g.GroupID IS NULL
        UNION SELECT FormableType FROM FormableNation_Claims WHERE (MinorCivType IS NULL) = (CivilizationType IS NULL)
            OR Mode NOT IN ('UNION', 'ALLY', 'ABSORB', 'OWN')""").fetchall()
    if bad:
        sys.exit(f"SQL reference errors: {bad}")
    unknown = db.execute("""SELECT MinorCivType FROM FormableNation_Claims WHERE MinorCivType IS NOT NULL
            AND MinorCivType NOT IN (SELECT Type FROM MinorCivilizations)
        UNION SELECT CivilizationType FROM FormableNation_Claims WHERE CivilizationType IS NOT NULL
            AND CivilizationType NOT IN (SELECT Type FROM Civilizations)
        UNION SELECT MinorCivType FROM FormableNation_OrganisationMembers WHERE MinorCivType IS NOT NULL
            AND MinorCivType NOT IN (SELECT Type FROM MinorCivilizations)
        UNION SELECT EraType FROM FormableNation_EraSettings WHERE EraType NOT IN (SELECT Type FROM Eras)
        UNION SELECT PromotionType FROM Unit_FreePromotions WHERE UnitType LIKE 'UNIT_FN_%'
            AND PromotionType NOT IN (SELECT Type FROM UnitPromotions)""").fetchall()
    if unknown:
        sys.exit(f"Names not in the base/VP database: {unknown}")
    perks = db.execute("SELECT COUNT(*) FROM Units WHERE Type LIKE 'UNIT_FN_%'").fetchone()[0]
    replacements = db.execute("SELECT COUNT(*) FROM Policy_UnitClassReplacements WHERE PolicyType LIKE 'POLICY_FN_%'").fetchone()[0]
    if perks == 0 or perks != replacements:
        sys.exit(f"Unique units: {perks} created, {replacements} replacements")
    return db


def check_text_keys(db):
    """Every TXT_KEY used by SQL and Lua must exist in the text file."""
    defined = set(re.findall(r'Tag="(TXT_KEY_[A-Z0-9_]+)"', (HERE / TEXT[0]).read_text(encoding="utf-8")))
    used = set()
    for row in db.execute("SELECT Title, Description, ShortDescription, Adjective, Help, Quote FROM FormableNations "
                          "UNION ALL SELECT Description, NULL, NULL, NULL, NULL, NULL FROM FormableNation_ClaimGroups "
                          "UNION ALL SELECT Title, Help, Quote, NULL, NULL, NULL FROM FormableNation_Organisations"):
        used.update(v for v in row if v)
    for f in UI:
        if f.endswith(".lua"):
            used.update(re.findall(r'"(TXT_KEY_FN_[A-Z0-9_]+)"', (HERE / f).read_text(encoding="utf-8")))
    for f in SQL:
        used.update(re.findall(r"'(TXT_KEY_FN_[A-Z0-9_]+)'", (HERE / f).read_text(encoding="utf-8")))
    # Keys built at runtime from a prefix + state/mode/tier.
    for prefix, values in {
        "TXT_KEY_FN_CLAIM_": ["OWNED", "MARRIED", "ALLIED", "NOT_ALLIED", "AT_WAR", "VASSAL", "NOT_HELD", "ABSENT", "LOST", "BOUND"],
        "TXT_KEY_FN_TERM_": ["LEAD", "CONTESTED", "TREATMENT", "STRONGER", "RELIGION", "TRADE", "NEIGHBOURS", "TENURE",
                             "WAR", "UNHAPPY", "CONCEDE", "PRIVILEGE", "ASSERT",
                             "CONNECTED", "NOT_CONNECTED", "CITY_RELIGION", "GARRISON", "PUPPET", "CITY_TENURE", "DISTANCE",
                             "FOREIGN", "NATIONALISM", "OPINION", "AUTONOMY", "SUPPRESS",
                             "ORG_FOUNDER", "ORG_IDEOLOGY", "ORG_TRADE", "ORG_FRIENDS", "ORG_DENOUNCE", "OPTOUT",
                             "CREDIBILITY", "THREAT", "BURDEN_TARGET", "BURDEN_TRIBUTE"],
        "TXT_KEY_FN_KIND_": ["COLONY", "FOREIGN"],
        "TXT_KEY_FN_NOTIFY_": ["REVIVED", "RETURNED", "RELEASED", "INDEPENDENCE",
                               "REVIVED_S", "RETURNED_S", "RELEASED_S", "INDEPENDENCE_S"],
        "TXT_KEY_FN_ORG_DEPTH_": ["FUNCTIONAL", "INTERGOVERNMENTAL", "SUPRANATIONAL", "ALLIANCE"],
        "TXT_KEY_FN_CHARTER_OBLIGATION_": ["DEFENCE", "FULL", "CONSULT"],
        "TXT_KEY_FN_CHARTER_SCOPE_": ["GLOBAL", "REGIONAL"],
        "TXT_KEY_FN_CHARTER_BURDEN_": ["NONE", "TARGET", "TRIBUTE"],
        "TXT_KEY_FN_CHARTER_V_": ["DEFENCE", "FULL", "CONSULT", "GLOBAL", "REGIONAL", "NONE", "TARGET", "TRIBUTE"],
        "TXT_KEY_FN_CHARTER_T_": ["OBLIGATION", "SCOPE", "NOSEPARATEPEACE", "BURDEN", "HEGEMONIC", "OPENBORDERS"],
        "TXT_KEY_FN_MODE_": ["UNION", "ALLY", "ABSORB", "OWN"],
        "TXT_KEY_FN_TIER_": ["1", "2"],
    }.items():
        used.update(prefix + v for v in values)
    used = {k for k in used if k.startswith("TXT_KEY_FN_") and not k.endswith("_")}
    missing = sorted(used - defined)
    if missing:
        sys.exit(f"Missing text keys: {missing}")
    check_translations(db)


def check_translations(db):
    """Every translation has exactly the English keys and placeholders. German civ names (the keys a formation renames
    a civ to) carry the base game's grammatical forms: Description 3, Adjective 5, separated by |."""
    def rows(path):
        return dict(re.findall(r'<Row Tag="(TXT_KEY_FN_[A-Z0-9_]+)"><Text>(.*?)</Text>', (HERE / path).read_text(encoding="utf-8"), re.S))
    en = rows(TEXT[0])
    forms = {}
    for desc, adj in db.execute("SELECT Description, Adjective FROM FormableNations WHERE Description IS NOT NULL"):
        forms[desc], forms[adj] = 3, 5
    placeholders = lambda t: sorted(set(re.findall(r"\{\d_[A-Za-z]+\}", t)))
    for path in TEXT[1:]:
        tr = rows(path)
        if set(tr) != set(en):
            sys.exit(f"{path}: keys differ from English: missing {sorted(set(en) - set(tr))}, extra {sorted(set(tr) - set(en))}")
        for k, text in tr.items():
            if placeholders(text) != placeholders(en[k]):
                sys.exit(f"{path}: {k} placeholders {placeholders(text)} differ from English {placeholders(en[k])}")
            if "de_DE" in path and k in forms and len(text.split("|")) != forms[k]:
                sys.exit(f"{path}: {k} needs {forms[k]} forms separated by |")


def check_settings(db):
    defined = {r[0] for r in db.execute("SELECT Name FROM FormableNation_Settings")}
    used = set()
    for f in UI:
        if f.endswith(".lua"):
            used.update(re.findall(r'\bS\.([A-Z][A-Z0-9_]+)', (HERE / f).read_text(encoding="utf-8")))
    missing = sorted(used - defined)
    if missing:
        sys.exit(f"Missing settings: {missing}")


def run_harness():
    """Offline scenario tests against a mock of the game's Lua API (tests/harness.lua)."""
    subprocess.run([sys.executable, "-I", str(HERE / "tests/make_gameinfo.py")], check=True, stdout=subprocess.DEVNULL)
    result = subprocess.run(["lua5.1", "tests/harness.lua"], cwd=HERE, capture_output=True, text=True)
    report = [line for line in result.stdout.splitlines() if not line.startswith("[FN]")]
    if result.returncode != 0:
        sys.exit("Harness failed:\n" + "\n".join(report) + result.stderr)
    print(report[-1])


def md5(path):
    return hashlib.md5(path.read_bytes()).hexdigest().upper()


def merged_highlights():
    base = VP_HIGHLIGHTS.read_text(encoding="utf-8-sig")
    ours = (HERE / "Overlays/FN_Styles.xml").read_text(encoding="utf-8")
    if "</Highlights>" not in base:
        sys.exit(f"Unexpected format: {VP_HIGHLIGHTS}")
    return base.replace("</Highlights>", "\n\t<!-- Formable Nations -->\n" + ours + "</Highlights>")


def package():
    out = HERE / "build" / MOD_NAME
    if out.exists():
        shutil.rmtree(out)
    for f in SQL + TEXT + UI:
        (out / f).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HERE / f, out / f)
    (out / "UI/Highlights.xml").write_text(merged_highlights(), encoding="utf-8")

    import_files = UI + ["UI/Highlights.xml"]
    files = "\n".join(
        f'    <File md5="{md5(out / f)}" import="{1 if f in import_files else 0}">{f}</File>'
        for f in SQL + TEXT + import_files)
    actions = "\n".join(f"      <UpdateDatabase>{f}</UpdateDatabase>" for f in SQL + TEXT)
    modinfo = f'''<?xml version="1.0" encoding="utf-8"?>
<Mod id="{MOD_ID}" version="{MOD_VERSION}">
  <Properties>
    <Name>{MOD_NAME}</Name>
    <Teaser>(5.4.6) Unions, unifications, independence movements and historical successor states</Teaser>
    <Description>Proclaim historically grounded unions and states: the Polish-Lithuanian Commonwealth, Austria-Hungary, the Holy Roman Empire, the German Empire, Great Britain, each with its own perks and unique unit. Union partners can drift apart and secede; colonies and conquered peoples can win independence or restore a fallen nation. City-States stand in for peoples without a civilization; unions are outlined on the map. Single player. Part of CivVNeo.</Description>
    <Authors>CivVNeo</Authors>
    <HideSetupGame>0</HideSetupGame>
    <AffectsSavedGames>1</AffectsSavedGames>
    <SupportsSinglePlayer>1</SupportsSinglePlayer>
    <SupportsMultiplayer>0</SupportsMultiplayer>
    <SupportsHotSeat>0</SupportsHotSeat>
    <SupportsMac>1</SupportsMac>
    <ReloadAudioSystem>0</ReloadAudioSystem>
    <ReloadLandmarkSystem>0</ReloadLandmarkSystem>
    <ReloadStrategicViewSystem>0</ReloadStrategicViewSystem>
    <ReloadUnitSystem>0</ReloadUnitSystem>
  </Properties>
  <Dependencies>
    <Mod id="d1b6328c-ff44-4b0d-aad7-c657f83610cd" minversion="151" maxversion="999" title="(1) Community Patch" />
    <Mod id="8411a7a8-dad3-4622-a18e-fcc18324c799" minversion="17" maxversion="999" title="(2) Vox Populi" />
  </Dependencies>
  <Blocks />
  <Files>
{files}
  </Files>
  <Actions>
    <OnModActivated>
{actions}
    </OnModActivated>
  </Actions>
  <EntryPoints>
    <EntryPoint type="InGameUIAddin" file="UI/FormableNations.xml">
      <Name>Formable Nations</Name>
      <Description>Formable Nations panel, rules and union outlines</Description>
    </EntryPoint>
  </EntryPoints>
</Mod>
'''
    (out / f"{MOD_NAME} (v {MOD_VERSION}).modinfo").write_text(modinfo, encoding="utf-8")
    subprocess.run(["xmllint", "--noout", str(out / "UI/Highlights.xml"),
                    str(out / f"{MOD_NAME} (v {MOD_VERSION}).modinfo")], check=True)
    return out


def install(out):
    dest = USER / "MODS" / MOD_NAME
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(out, dest)
    cache = USER / "cache"
    print(f"Installed to {dest}")
    if cache.exists():
        print(f"Note: delete {cache} if the game shows stale database content.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", action="store_true", help="copy the package into the game's MODS folder")
    args = ap.parse_args()
    check_lua()
    check_xml(TEXT + ["UI/FormableNations.xml"])
    db = check_sql()
    check_text_keys(db)
    check_settings(db)
    run_harness()
    out = package()
    print(f"Packaged {out}")
    if args.install:
        install(out)


if __name__ == "__main__":
    main()
