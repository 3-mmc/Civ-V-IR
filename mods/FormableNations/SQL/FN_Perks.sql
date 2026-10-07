-- Formable Nations v0.3 perks: unique units, economic perks and proclamation golden ages.
-- Design: docs/formable-nations-design.md, "Perks of formed nations".

------------------------------------------------------------------------------
-- Proclamation: a golden age when a State (Tier II) is proclaimed. Turns at Standard speed;
-- the engine scales them like any other golden age.
------------------------------------------------------------------------------
UPDATE FormableNations SET GoldenAgeTurns = 8 WHERE Tier = 2;

------------------------------------------------------------------------------
-- Economic perks, added to the stage's hidden policy (see FN_Data.sql for the base bonuses).
------------------------------------------------------------------------------
-- Habsburg Monarchy: "Let others wage war; you, happy Austria, marry."
UPDATE Policies SET MinorGoldFriendshipMod = 25 WHERE Type = 'POLICY_FN_HABSBURG';
-- German Empire: the Zollverein customs union.
UPDATE Policies SET InternalTradeRouteYieldModifier = 15 WHERE Type = 'POLICY_FN_GERMAN_EMPIRE';

-- Polish-Lithuanian Commonwealth: grain shipped down the Vistula through Gdansk, the "granary of Europe".
INSERT INTO Policy_ResourceYieldChanges (PolicyType, ResourceType, YieldType, Yield)
SELECT 'POLICY_FN_COMMONWEALTH', 'RESOURCE_WHEAT', 'YIELD_FOOD', 1 WHERE EXISTS (SELECT 1 FROM Resources WHERE Type = 'RESOURCE_WHEAT')
UNION ALL
SELECT 'POLICY_FN_COMMONWEALTH', 'RESOURCE_WHEAT', 'YIELD_GOLD', 1 WHERE EXISTS (SELECT 1 FROM Resources WHERE Type = 'RESOURCE_WHEAT');

-- Austria-Hungary: the Vienna State Opera and Budapest's opera house. Great Britain: the Royal Navy's harbours.
INSERT INTO Policy_BuildingClassYieldChanges (PolicyType, BuildingClassType, YieldType, YieldChange)
SELECT 'POLICY_FN_AUSTRIA_HUNGARY', 'BUILDINGCLASS_OPERA_HOUSE', 'YIELD_CULTURE', 2 WHERE EXISTS (SELECT 1 FROM BuildingClasses WHERE Type = 'BUILDINGCLASS_OPERA_HOUSE')
UNION ALL
SELECT 'POLICY_FN_GREAT_BRITAIN', 'BUILDINGCLASS_HARBOR', 'YIELD_GOLD', 1 WHERE EXISTS (SELECT 1 FROM BuildingClasses WHERE Type = 'BUILDINGCLASS_HARBOR');

------------------------------------------------------------------------------
-- Unique units. VP's own pattern for policy units (B-17, T-34): a unit class of its own, gated by Units.PolicyType,
-- and Policy_UnitClassReplacements so it replaces the generic unit for that player only (a civ's own unique unit
-- for the same class is kept). Each unit is a copy of its base unit as VP leaves it (stats, art, AI, upgrades),
-- plus CombatBonus and one free promotion. A missing base unit or promotion skips that unit instead of failing.
-- BaseUnit must be unique within this table: the copy is matched back to its spec by the base unit's Type.
------------------------------------------------------------------------------
CREATE TEMP TABLE FN_UniqueUnits (
	UnitType text, UnitClassType text, BaseUnit text, PolicyType text, CombatBonus integer, PromotionType text,
	Description text, Help text, Strategy text, Civilopedia text
);
INSERT INTO FN_UniqueUnits VALUES
	('UNIT_FN_REICHSRITTER', 'UNITCLASS_FN_REICHSRITTER', 'UNIT_KNIGHT', 'POLICY_FN_HRE', 2, 'PROMOTION_CHARGE',
		'TXT_KEY_FN_UNIT_REICHSRITTER', 'TXT_KEY_FN_UNIT_REICHSRITTER_HELP', 'TXT_KEY_FN_UNIT_REICHSRITTER_HELP', 'TXT_KEY_FN_UNIT_REICHSRITTER_PEDIA'),
	('UNIT_FN_HAIDUK', 'UNITCLASS_FN_HAIDUK', 'UNIT_MUSKETMAN', 'POLICY_FN_COMMONWEALTH', 2, 'PROMOTION_COVER_1',
		'TXT_KEY_FN_UNIT_HAIDUK', 'TXT_KEY_FN_UNIT_HAIDUK_HELP', 'TXT_KEY_FN_UNIT_HAIDUK_HELP', 'TXT_KEY_FN_UNIT_HAIDUK_PEDIA'),
	('UNIT_FN_HIGHLANDER', 'UNITCLASS_FN_HIGHLANDER', 'UNIT_RIFLEMAN', 'POLICY_FN_GREAT_BRITAIN', 2, 'PROMOTION_CHARGE',
		'TXT_KEY_FN_UNIT_HIGHLANDER', 'TXT_KEY_FN_UNIT_HIGHLANDER_HELP', 'TXT_KEY_FN_UNIT_HIGHLANDER_HELP', 'TXT_KEY_FN_UNIT_HIGHLANDER_PEDIA'),
	('UNIT_FN_KAISERSCHUETZE', 'UNITCLASS_FN_KAISERSCHUETZE', 'UNIT_GREAT_WAR_INFANTRY', 'POLICY_FN_AUSTRIA_HUNGARY', 3, 'PROMOTION_DRILL_1',
		'TXT_KEY_FN_UNIT_KAISERSCHUETZE', 'TXT_KEY_FN_UNIT_KAISERSCHUETZE_HELP', 'TXT_KEY_FN_UNIT_KAISERSCHUETZE_HELP', 'TXT_KEY_FN_UNIT_KAISERSCHUETZE_PEDIA'),
	('UNIT_FN_UHLAN', 'UNITCLASS_FN_UHLAN', 'UNIT_CAVALRY', 'POLICY_FN_GERMAN_EMPIRE', 2, 'PROMOTION_SENTRY',
		'TXT_KEY_FN_UNIT_UHLAN', 'TXT_KEY_FN_UNIT_UHLAN_HELP', 'TXT_KEY_FN_UNIT_UHLAN_HELP', 'TXT_KEY_FN_UNIT_UHLAN_PEDIA');

-- Copy every column of the base units, then rewrite identity and stats. In one UPDATE all right-hand sides see the
-- old row, so the lookups by Type still find the spec while Type itself is rewritten.
CREATE TEMP TABLE FN_UnitCopy AS SELECT * FROM Units WHERE 0;
INSERT INTO FN_UnitCopy SELECT u.* FROM Units u JOIN FN_UniqueUnits s ON s.BaseUnit = u.Type;
UPDATE FN_UnitCopy SET
	ID = NULL,
	Class = (SELECT UnitClassType FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	PolicyType = (SELECT PolicyType FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Combat = Combat + (SELECT CombatBonus FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Description = (SELECT Description FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Help = (SELECT Help FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Strategy = (SELECT Strategy FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Civilopedia = (SELECT Civilopedia FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type),
	Type = (SELECT UnitType FROM FN_UniqueUnits WHERE BaseUnit = FN_UnitCopy.Type);

INSERT INTO UnitClasses (Type, Description, DefaultUnit) SELECT Class, Description, Type FROM FN_UnitCopy;
INSERT INTO Units SELECT * FROM FN_UnitCopy;

-- Upgrades, AI roles, flavours, resource needs and promotions follow the base unit.
INSERT INTO Unit_ClassUpgrades (UnitType, UnitClassType)
	SELECT s.UnitType, x.UnitClassType FROM Unit_ClassUpgrades x JOIN FN_UniqueUnits s ON s.BaseUnit = x.UnitType
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);
INSERT INTO Unit_AITypes (UnitType, UnitAIType)
	SELECT s.UnitType, x.UnitAIType FROM Unit_AITypes x JOIN FN_UniqueUnits s ON s.BaseUnit = x.UnitType
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);
INSERT INTO Unit_Flavors (UnitType, FlavorType, Flavor)
	SELECT s.UnitType, x.FlavorType, x.Flavor FROM Unit_Flavors x JOIN FN_UniqueUnits s ON s.BaseUnit = x.UnitType
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);
INSERT INTO Unit_ResourceQuantityRequirements (UnitType, ResourceType, Cost)
	SELECT s.UnitType, x.ResourceType, x.Cost FROM Unit_ResourceQuantityRequirements x JOIN FN_UniqueUnits s ON s.BaseUnit = x.UnitType
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);
INSERT INTO Unit_FreePromotions (UnitType, PromotionType)
	SELECT s.UnitType, x.PromotionType FROM Unit_FreePromotions x JOIN FN_UniqueUnits s ON s.BaseUnit = x.UnitType
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);
INSERT INTO Unit_FreePromotions (UnitType, PromotionType)
	SELECT s.UnitType, s.PromotionType FROM FN_UniqueUnits s
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType) AND EXISTS (SELECT 1 FROM UnitPromotions WHERE Type = s.PromotionType)
	AND NOT EXISTS (SELECT 1 FROM Unit_FreePromotions WHERE UnitType = s.UnitType AND PromotionType = s.PromotionType);

INSERT INTO Policy_UnitClassReplacements (PolicyType, ReplacedUnitClassType, ReplacementUnitClassType)
	SELECT s.PolicyType, b.Class, s.UnitClassType FROM FN_UniqueUnits s JOIN Units b ON b.Type = s.BaseUnit
	WHERE EXISTS (SELECT 1 FROM Units WHERE Type = s.UnitType);

DROP TABLE FN_UnitCopy;
DROP TABLE FN_UniqueUnits;
