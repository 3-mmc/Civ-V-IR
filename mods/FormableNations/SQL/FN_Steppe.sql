-- Formable Nations v0.7: the Huns, Shoshone and Zulu, with achievement requirements and breakaway preferences.

-- Zulu: oYengweni, seat of Dingiswayo's Mthethwa paramountcy (formation-only, like FN_CityStates.sql).
INSERT INTO MinorCivilizations
	(Type, Description, Civilopedia, ShortDescription, Adjective, ArtDefineTag, DefaultPlayerColor, ArtStyleType, ArtStyleSuffix, ArtStylePrefix, MinorCivTrait, Playable)
VALUES
	('MINOR_CIV_FN_OYENGWENI', 'TXT_KEY_FN_CS_OYENGWENI', 'TXT_KEY_FN_CS_OYENGWENI_PEDIA', 'TXT_KEY_FN_CS_OYENGWENI', 'TXT_KEY_FN_CS_OYENGWENI_ADJ',
		'ART_DEF_CIVILIZATION_MINOR', 'PLAYERCOLOR_MINOR_ZULU', 'ARTSTYLE_MIDDLE_EAST', '_AFRI', 'AFRICAN', 'MINOR_TRAIT_MILITARISTIC', 0);
INSERT INTO MinorCivilization_CityNames (MinorCivType, CityName) VALUES ('MINOR_CIV_FN_OYENGWENI', 'TXT_KEY_FN_CS_OYENGWENI');
INSERT INTO FormableNation_CityStateSounds (MinorCivType, AudioScript) VALUES ('MINOR_CIV_FN_OYENGWENI', 'AS2D_MINOR_CIV_ZANZIBAR');

INSERT INTO FormableNation_BreakawayPreferences (CivilizationType, MinorCivType, Priority) VALUES
	('CIVILIZATION_ZULU', 'MINOR_CIV_KWA_BULAWAYO', 1);

INSERT INTO Policies (Type, Description, Help, IsDummy) VALUES
	('POLICY_FN_MTHETHWA',        'TXT_KEY_FN_MTHETHWA_TITLE',        'TXT_KEY_FN_MTHETHWA_HELP',        1),
	('POLICY_FN_ZULU_KINGDOM',    'TXT_KEY_FN_ZULU_KINGDOM_TITLE',    'TXT_KEY_FN_ZULU_KINGDOM_HELP',    1),
	('POLICY_FN_HORSE_REVOLUTION','TXT_KEY_FN_HORSE_REVOLUTION_TITLE','TXT_KEY_FN_HORSE_REVOLUTION_HELP',1);

UPDATE Policies SET MilitaryProductionModifier = 10 WHERE Type = 'POLICY_FN_ZULU_KINGDOM';
INSERT INTO Policy_CapitalYieldChanges (PolicyType, YieldType, Yield) VALUES
	('POLICY_FN_MTHETHWA', 'YIELD_PRODUCTION', 2), ('POLICY_FN_MTHETHWA', 'YIELD_CULTURE', 2),
	('POLICY_FN_ZULU_KINGDOM', 'YIELD_CULTURE', 3);
INSERT INTO Policy_UnitCombatFreeExperiences (PolicyType, UnitCombatType, FreeExperience) VALUES
	('POLICY_FN_ZULU_KINGDOM', 'UNITCOMBAT_MELEE', 15),
	('POLICY_FN_HORSE_REVOLUTION', 'UNITCOMBAT_MOUNTED', 15);
INSERT INTO Policy_UnitCombatProductionModifiers (PolicyType, UnitCombatType, ProductionModifier) VALUES
	('POLICY_FN_HORSE_REVOLUTION', 'UNITCOMBAT_MOUNTED', 25);
INSERT INTO Policy_ImprovementYieldChanges (PolicyType, ImprovementType, YieldType, Yield) VALUES
	('POLICY_FN_HORSE_REVOLUTION', 'IMPROVEMENT_PASTURE', 'YIELD_PRODUCTION', 1),
	('POLICY_FN_HORSE_REVOLUTION', 'IMPROVEMENT_PASTURE', 'YIELD_CULTURE', 1);

INSERT INTO FormableNations
	(Type, Chain, Stage, Tier, IsUnion, CivilizationType, Title, Description, ShortDescription, Adjective, Help, Quote, MinEra, MaxEra, PrereqStage, PrereqTurns, PolicyType)
VALUES
	('FN_MTHETHWA', 'ZULU', 1, 1, 1, 'CIVILIZATION_ZULU', 'TXT_KEY_FN_MTHETHWA_TITLE', NULL, NULL, NULL,
		'TXT_KEY_FN_MTHETHWA_HELP', 'TXT_KEY_FN_MTHETHWA_QUOTE', 'ERA_RENAISSANCE', 'ERA_INDUSTRIAL', NULL, 0, 'POLICY_FN_MTHETHWA'),
	('FN_ZULU_KINGDOM', 'ZULU', 2, 2, 0, 'CIVILIZATION_ZULU', 'TXT_KEY_FN_ZULU_KINGDOM_TITLE', NULL, NULL, NULL,
		'TXT_KEY_FN_ZULU_KINGDOM_HELP', 'TXT_KEY_FN_ZULU_KINGDOM_QUOTE', 'ERA_RENAISSANCE', 'ERA_INDUSTRIAL', 'FN_MTHETHWA', 10, 'POLICY_FN_ZULU_KINGDOM'),
	-- An achievement formation: no claims, only the state of the Shoshone nation's herds and riders.
	('FN_HORSE_REVOLUTION', 'SHOSHONE', 1, 2, 0, 'CIVILIZATION_SHOSHONE', 'TXT_KEY_FN_HORSE_REVOLUTION_TITLE', NULL, NULL, NULL,
		'TXT_KEY_FN_HORSE_REVOLUTION_HELP', 'TXT_KEY_FN_HORSE_REVOLUTION_QUOTE', 'ERA_RENAISSANCE', 'ERA_INDUSTRIAL', NULL, 0, 'POLICY_FN_HORSE_REVOLUTION');

INSERT INTO FormableNation_ClaimGroups (FormableType, GroupID, NumRequired, Description) VALUES
	('FN_MTHETHWA', 1, 1, 'TXT_KEY_FN_GROUP_MTHETHWA'),
	('FN_ZULU_KINGDOM', 1, 1, 'TXT_KEY_FN_GROUP_MTHETHWA');
INSERT INTO FormableNation_Claims (FormableType, GroupID, MinorCivType, CivilizationType, Mode) VALUES
	('FN_MTHETHWA', 1, 'MINOR_CIV_FN_OYENGWENI', NULL, 'UNION'),
	('FN_ZULU_KINGDOM', 1, 'MINOR_CIV_FN_OYENGWENI', NULL, 'ABSORB');

INSERT INTO FormableNation_Achievements (FormableType, Kind, Target, Amount, Description) VALUES
	('FN_HORSE_REVOLUTION', 'RESOURCE', 'RESOURCE_HORSE', 4, 'TXT_KEY_FN_ACH_HORSES'),
	('FN_HORSE_REVOLUTION', 'IMPROVEMENT', 'IMPROVEMENT_PASTURE', 3, 'TXT_KEY_FN_ACH_PASTURES'),
	('FN_HORSE_REVOLUTION', 'UNITCOMBAT', 'UNITCOMBAT_MOUNTED', 3, 'TXT_KEY_FN_ACH_RIDERS');

-- Huns: tribute in exchange for peace, as the Eastern Roman Empire paid Attila. Only the Huns found it; neighbours
-- they outmatch join out of fear; members pay tribute, cannot be attacked by the Huns, and are called to the Huns' wars.
INSERT INTO FormableNation_Organisations
	(Type, Depth, Title, Help, Quote, MinEra, MaxEra, MinMembers, OpenBorders, MemberCohesion, NoWarBetweenMembers,
	 Obligation, Scope, NoSeparatePeace, Burden, Hegemonic, Custom, FounderCivilization, OpenToAll, JoinRule)
VALUES
	('ORG_HUNNIC_TRIBUTE', 'ALLIANCE', 'TXT_KEY_FN_ORG_HUNNIC_TRIBUTE_TITLE', NULL, 'TXT_KEY_FN_ORG_HUNNIC_TRIBUTE_QUOTE',
		'ERA_CLASSICAL', 'ERA_MEDIEVAL', 2, 0, 1, 1, 'DEFENCE', 'GLOBAL', 0, 'TRIBUTE', 1, 0, 'CIVILIZATION_HUNS', 1, 'FEAR');
