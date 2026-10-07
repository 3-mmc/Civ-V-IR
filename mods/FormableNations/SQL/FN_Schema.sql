-- Formable Nations: data model. Design: CivVNeo/docs/formable-nations-design.md

-- One row per stage. Stages of the same Chain belong to one people (e.g. Poland: Krewo -> Commonwealth).
CREATE TABLE IF NOT EXISTS FormableNations (
	ID integer PRIMARY KEY AUTOINCREMENT,
	Type text NOT NULL UNIQUE,
	Chain text NOT NULL,
	Stage integer NOT NULL DEFAULT 1,
	Tier integer NOT NULL DEFAULT 1,                         -- 1 union, 2 state (3 bloc reserved)
	IsUnion boolean NOT NULL DEFAULT 0,                      -- maintained each turn; dissolves if its claims fail
	CivilizationType text NOT NULL REFERENCES Civilizations(Type),
	Title text NOT NULL,                                     -- stage name shown in the panel
	Description text,                                        -- civ rename keys; NULL keeps the current name
	ShortDescription text,
	Adjective text,
	Help text,                                               -- bonus summary
	Quote text,                                              -- historical note
	MinEra text NOT NULL REFERENCES Eras(Type),
	MaxEra text NOT NULL REFERENCES Eras(Type),
	PrereqStage text REFERENCES FormableNations(Type),
	PrereqTurns integer NOT NULL DEFAULT 0,                  -- prereq is a union: turns every partner must stay integrated;
	                                                         -- otherwise: turns the prereq must have been held (Standard speed)
	PolicyType text NOT NULL REFERENCES Policies(Type),     -- hidden dummy policy carrying the bonus (and unique unit, FN_Perks.sql)
	GoldenAgeTurns integer NOT NULL DEFAULT 0                -- golden age on proclamation (Standard speed)
);

-- A stage needs NumRequired claims met in every group. A group that cannot be met in this game makes the stage impossible.
CREATE TABLE IF NOT EXISTS FormableNation_ClaimGroups (
	FormableType text NOT NULL REFERENCES FormableNations(Type),
	GroupID integer NOT NULL,
	NumRequired integer NOT NULL DEFAULT 1,
	Description text                                         -- e.g. "Hungary"
);

-- Claim on a city-state's or major civ's original capital. Exactly one of MinorCivType / CivilizationType.
-- Mode: UNION (allied N turns or married / vassal; maintained), ALLY (allied now), ABSORB (as UNION, then annexed), OWN.
CREATE TABLE IF NOT EXISTS FormableNation_Claims (
	FormableType text NOT NULL REFERENCES FormableNations(Type),
	GroupID integer NOT NULL,
	MinorCivType text REFERENCES MinorCivilizations(Type),
	CivilizationType text REFERENCES Civilizations(Type),
	Mode text NOT NULL DEFAULT 'UNION'
);

-- City-State types a seceding colony can become when no City-State is named like the city (FN_Independence.sql).
CREATE TABLE IF NOT EXISTS FormableNation_ColonialStates (
	MinorCivType text NOT NULL REFERENCES MinorCivilizations(Type)
);

-- Era thresholds by type, so mods that insert eras (e.g. Enlightenment Era) do not shift them.
CREATE TABLE IF NOT EXISTS FormableNation_EraSettings (
	Name text NOT NULL UNIQUE,
	EraType text NOT NULL REFERENCES Eras(Type)
);

-- Sound clip for each City-State this mod adds (FN_CityStates.sql). build.py --install writes them into VP's
-- MinorCivSounds_VoxPopuli.xml in the game folder, which VP's Expansion2.Civ5Pkg loads.
CREATE TABLE IF NOT EXISTS FormableNation_CityStateSounds (
	MinorCivType text NOT NULL REFERENCES MinorCivilizations(Type),
	AudioScript text NOT NULL
);
