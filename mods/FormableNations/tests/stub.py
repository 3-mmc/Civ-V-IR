"""In-memory stand-in for the game database, shared by build.py's SQL check and make_gameinfo.py.

Static rows come from stub_rows.sql (base game names plus VP's City-States). The Policies and Units tables are
built with exactly the columns the VP DLL reads (CvPolicyClasses.cpp, CvUnitClasses.cpp, CvBaseInfo), so a
misspelt or non-existent column fails here instead of only in the game's Database.log. Without the upstream
source checkout, a small fallback column list is used and that guarantee is lost (a warning is printed).
"""
import re
import os
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REFERENCES = Path(os.environ.get("CIVVNEO_REFERENCE_ROOT", str(HERE.parents[3])))
DLL = REFERENCES / "upstream/Community-Patch-DLL/CvGameCoreDLL_Expansion2"
BASE_INFO = ["Type", "Description", "Civilopedia", "Strategy", "Help", "DisabledHelp", "Text"]  # CvBaseInfo::CacheResults
FALLBACK = {
    "CvPolicyClasses.cpp": ["PolicyBranchType", "IsDummy", "FreeWCVotes", "MilitaryProductionModifier", "EmbarkedExtraMoves",
                            "MinorGoldFriendshipMod", "InternalTradeRouteYieldModifier"],
    "CvUnitClasses.cpp": ["Class", "PolicyType", "Combat", "RangedCombat", "Moves", "Domain", "PrereqTech"],
}

# Child tables of Policies the DLL reads, created with the columns its queries use.
POLICY_TABLES = """
    CREATE TABLE Policy_CapitalYieldChanges (PolicyType text, YieldType text, Yield integer);
    CREATE TABLE Policy_YieldModifiers (PolicyType text, YieldType text, Yield integer);
    CREATE TABLE Policy_ResourceYieldChanges (PolicyType text, ResourceType text, YieldType text, Yield integer);
    CREATE TABLE Policy_BuildingClassYieldChanges (PolicyType text, BuildingClassType text, YieldType text, YieldChange integer);
    CREATE TABLE Policy_UnitClassReplacements (PolicyType text, ReplacedUnitClassType text, ReplacementUnitClassType text);
    CREATE TABLE Policy_UnitCombatFreeExperiences (PolicyType text, UnitCombatType text, FreeExperience integer);
    CREATE TABLE Policy_UnitCombatProductionModifiers (PolicyType text, UnitCombatType text, ProductionModifier integer);
    CREATE TABLE Policy_ImprovementYieldChanges (PolicyType text, ImprovementType text, YieldType text, Yield integer);
    CREATE TABLE CustomModOptions (Class integer, Name text, Value integer);
    INSERT INTO CustomModOptions VALUES (3, 'EVENTS_WAR_AND_PEACE', 0);
"""


def dll_columns(cpp):
    path = DLL / cpp
    if not path.exists():
        print(f"warning: {path} not found; column names are only checked against a fallback list", file=sys.stderr)
        return FALLBACK[cpp]
    return sorted(set(re.findall(r'Get(?:Int|Bool|Text|Float)\("([A-Za-z0-9_]+)"\)', path.read_text(encoding="utf-8", errors="replace"))))


def info_table(db, name, cpp):
    cols = [c for c in dll_columns(cpp) if c not in BASE_INFO and c != "ID"]
    defs = ["ID integer PRIMARY KEY AUTOINCREMENT", "Type text NOT NULL UNIQUE"] + \
           [f'"{c}" text' for c in BASE_INFO if c != "Type"] + [f'"{c}" DEFAULT NULL' for c in cols]
    db.execute(f"CREATE TABLE {name} ({', '.join(defs)})")


def build_stub():
    db = sqlite3.connect(":memory:")
    info_table(db, "Policies", "CvPolicyClasses.cpp")
    info_table(db, "Units", "CvUnitClasses.cpp")
    db.executescript(POLICY_TABLES)
    db.executescript((HERE / "stub_rows.sql").read_text(encoding="utf-8"))
    db.execute("INSERT INTO Units (ID, Type, Class, Description, Help, Strategy, Civilopedia, Combat, RangedCombat, Moves, Domain, PrereqTech) "
               "SELECT * FROM StubUnits")
    db.execute("DROP TABLE StubUnits")
    return db
