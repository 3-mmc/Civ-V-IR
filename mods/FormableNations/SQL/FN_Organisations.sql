-- International organisations (Tier III). Depth: FUNCTIONAL (one game system), INTERGOVERNMENTAL (multi-purpose,
-- sovereign members) or SUPRANATIONAL (EU-style: shared rules, members keep a cohesion score and may vote to leave).
CREATE TABLE IF NOT EXISTS FormableNation_Organisations (
	ID integer PRIMARY KEY AUTOINCREMENT,
	Type text NOT NULL UNIQUE,
	Depth text NOT NULL,
	Title text NOT NULL,
	Help text,
	Quote text,
	MinEra text NOT NULL REFERENCES Eras(Type),   -- founder must have reached it
	MaxEra text REFERENCES Eras(Type),            -- dissolves once its founder passes it; NULL = never
	MinMembers integer NOT NULL DEFAULT 3,
	RequiresCoast boolean NOT NULL DEFAULT 0,     -- member capital must be coastal
	ResourceType text REFERENCES Resources(Type), -- members must own at least MinResource of it
	MinResource integer NOT NULL DEFAULT 0,
	TradeRouteGold integer NOT NULL DEFAULT 0,    -- per turn, per trade route a major member runs to another member
	ResourceGold integer NOT NULL DEFAULT 0,      -- per turn, per unit of ResourceType a major member owns (max 10 units)
	MinorInfluence integer NOT NULL DEFAULT 0,    -- per turn, each major member's Influence with each City-State member
	OpenBorders boolean NOT NULL DEFAULT 0,       -- major members keep open borders with each other
	PolicyType text REFERENCES Policies(Type),    -- optional dummy policy for major members
	PrereqOrg text,                               -- founder must belong to it; founding merges it into this one
	MemberCohesion boolean NOT NULL DEFAULT 0,    -- major members keep a cohesion score and can vote to leave
	NoWarBetweenMembers boolean NOT NULL DEFAULT 0, -- members cannot declare war on each other (VP war events)
	-- Alliances (Depth ALLIANCE, FN_Alliances.sql): the charter's terms.
	Obligation text,                              -- DEFENCE (attack on one = on all), FULL (also members' wars of aggression), CONSULT (a call members may refuse)
	Scope text,                                   -- GLOBAL, or REGIONAL (only aggressors within ALLIANCE_REGION_TILES of the attacked member)
	NoSeparatePeace boolean NOT NULL DEFAULT 0,   -- no peace with the enemy while the member who was attacked still fights
	Burden text,                                  -- NONE, TARGET (members keep their military near the alliance average), TRIBUTE (members pay the leader)
	Hegemonic boolean NOT NULL DEFAULT 0,         -- the leader's own wars call members in; members leave only by referendum
	Custom boolean NOT NULL DEFAULT 0,            -- a slot for a player-drafted pact: name and terms chosen at founding
	FounderCivilization text REFERENCES Civilizations(Type), -- only this civilization may found it (e.g. China's tributary system)
	OpenToAll boolean NOT NULL DEFAULT 0,         -- any civilization or City-State may join (no member list)
	JoinRule text                                 -- FEAR: members join because the leader outmatches them nearby
);

-- Eligible peoples. No CivilizationType rows: every major civ may join. No MinorCivType rows: no City-State may join,
-- unless the organisation has a ResourceType, in which case any City-State owning it may.
CREATE TABLE IF NOT EXISTS FormableNation_OrganisationMembers (
	OrganisationType text NOT NULL REFERENCES FormableNation_Organisations(Type),
	CivilizationType text REFERENCES Civilizations(Type),
	MinorCivType text REFERENCES MinorCivilizations(Type)
);

INSERT INTO FormableNation_Organisations
	(Type, Depth, Title, Help, Quote, MinEra, MaxEra, MinMembers, RequiresCoast, ResourceType, MinResource, TradeRouteGold, ResourceGold, MinorInfluence, OpenBorders)
VALUES
	('ORG_HANSEATIC_LEAGUE', 'FUNCTIONAL', 'TXT_KEY_FN_ORG_HANSE_TITLE', 'TXT_KEY_FN_ORG_HANSE_HELP', 'TXT_KEY_FN_ORG_HANSE_QUOTE',
		'ERA_MEDIEVAL', 'ERA_RENAISSANCE', 3, 1, NULL, 0, 3, 0, 1, 0),
	('ORG_OPEC', 'FUNCTIONAL', 'TXT_KEY_FN_ORG_OPEC_TITLE', 'TXT_KEY_FN_ORG_OPEC_HELP', 'TXT_KEY_FN_ORG_OPEC_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 0, 'RESOURCE_OIL', 2, 0, 1, 0, 0),
	('ORG_ARAB_LEAGUE', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_ARAB_LEAGUE_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_ARAB_LEAGUE_QUOTE',
		'ERA_MODERN', NULL, 3, 0, NULL, 0, 2, 0, 1, 1),
	('ORG_AFRICAN_UNION', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_AFRICAN_UNION_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_AFRICAN_UNION_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 0, NULL, 0, 2, 0, 1, 1),
	('ORG_ASEAN', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_ASEAN_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_ASEAN_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 0, NULL, 0, 2, 0, 1, 1),
	('ORG_NORDIC_COUNCIL', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_NORDIC_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_NORDIC_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 0, NULL, 0, 2, 0, 1, 1),
	('ORG_MERCOSUR', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_MERCOSUR_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_MERCOSUR_QUOTE',
		'ERA_FUTURE', NULL, 2, 0, NULL, 0, 2, 0, 1, 1);

-- The European chain: Coal and Steel Community (1951) -> Economic Community (1957) -> Union (1993).
INSERT INTO Policies (Type, Description, Help, IsDummy) VALUES
	('POLICY_FN_ORG_ECSC', 'TXT_KEY_FN_ORG_ECSC_TITLE', 'TXT_KEY_FN_ORG_ECSC_HELP', 1),
	('POLICY_FN_ORG_EEC', 'TXT_KEY_FN_ORG_EEC_TITLE', 'TXT_KEY_FN_ORG_EEC_HELP', 1),
	('POLICY_FN_ORG_EU', 'TXT_KEY_FN_ORG_EU_TITLE', 'TXT_KEY_FN_ORG_EU_HELP', 1);
UPDATE Policies SET FreeWCVotes = 1 WHERE Type = 'POLICY_FN_ORG_EU';
INSERT INTO Policy_YieldModifiers (PolicyType, YieldType, Yield) VALUES
	('POLICY_FN_ORG_ECSC', 'YIELD_PRODUCTION', 3),
	('POLICY_FN_ORG_EEC', 'YIELD_GOLD', 5),
	('POLICY_FN_ORG_EU', 'YIELD_GOLD', 5),
	('POLICY_FN_ORG_EU', 'YIELD_SCIENCE', 5);

INSERT INTO FormableNation_Organisations
	(Type, Depth, Title, Help, Quote, MinEra, MaxEra, MinMembers, RequiresCoast, ResourceType, MinResource, TradeRouteGold, ResourceGold,
	 MinorInfluence, OpenBorders, PolicyType, PrereqOrg, MemberCohesion, NoWarBetweenMembers)
VALUES
	('ORG_ECSC', 'FUNCTIONAL', 'TXT_KEY_FN_ORG_ECSC_TITLE', 'TXT_KEY_FN_ORG_ECSC_HELP', 'TXT_KEY_FN_ORG_ECSC_QUOTE',
		'ERA_MODERN', NULL, 3, 0, 'RESOURCE_COAL', 1, 0, 1, 0, 0, 'POLICY_FN_ORG_ECSC', NULL, 0, 0),
	('ORG_EEC', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_EEC_TITLE', 'TXT_KEY_FN_ORG_EEC_HELP', 'TXT_KEY_FN_ORG_EEC_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 0, NULL, 0, 3, 0, 1, 1, 'POLICY_FN_ORG_EEC', 'ORG_ECSC', 0, 0),
	('ORG_EU', 'SUPRANATIONAL', 'TXT_KEY_FN_ORG_EU_TITLE', 'TXT_KEY_FN_ORG_EU_HELP', 'TXT_KEY_FN_ORG_EU_QUOTE',
		'ERA_FUTURE', NULL, 4, 0, NULL, 0, 4, 0, 2, 1, 'POLICY_FN_ORG_EU', 'ORG_EEC', 1, 1);

-- Peace between members of a supranational organisation uses VP's PlayerCanDeclareWar event, which is off by default.
UPDATE CustomModOptions SET Value = 1 WHERE Name = 'EVENTS_WAR_AND_PEACE';

-- European members, shared by the whole chain.
CREATE TEMP TABLE FN_European (CivilizationType text, MinorCivType text);
INSERT INTO FN_European VALUES
	('CIVILIZATION_FRANCE', NULL), ('CIVILIZATION_GERMANY', NULL), ('CIVILIZATION_ROME', NULL), ('CIVILIZATION_NETHERLANDS', NULL),
	('CIVILIZATION_ENGLAND', NULL), ('CIVILIZATION_SPAIN', NULL), ('CIVILIZATION_PORTUGAL', NULL), ('CIVILIZATION_AUSTRIA', NULL),
	('CIVILIZATION_POLAND', NULL), ('CIVILIZATION_DENMARK', NULL), ('CIVILIZATION_SWEDEN', NULL), ('CIVILIZATION_CELTS', NULL),
	('CIVILIZATION_GREECE', NULL), ('CIVILIZATION_VENICE', NULL),
	(NULL, 'MINOR_CIV_BRUSSELS'), (NULL, 'MINOR_CIV_ANTWERP'), (NULL, 'MINOR_CIV_LISBON'), (NULL, 'MINOR_CIV_DUBLIN'),
	(NULL, 'MINOR_CIV_VIENNA'), (NULL, 'MINOR_CIV_WARSAW'), (NULL, 'MINOR_CIV_COPENHAGEN'), (NULL, 'MINOR_CIV_STOCKHOLM'),
	(NULL, 'MINOR_CIV_HELSINKI'), (NULL, 'MINOR_CIV_PRAGUE'), (NULL, 'MINOR_CIV_BRATISLAVA'), (NULL, 'MINOR_CIV_BUDAPEST'),
	(NULL, 'MINOR_CIV_VILNIUS'), (NULL, 'MINOR_CIV_RIGA'), (NULL, 'MINOR_CIV_SOFIA'), (NULL, 'MINOR_CIV_BUCHAREST'),
	(NULL, 'MINOR_CIV_RAGUSA'), (NULL, 'MINOR_CIV_VALLETTA'), (NULL, 'MINOR_CIV_FLORENCE'), (NULL, 'MINOR_CIV_MILAN'),
	(NULL, 'MINOR_CIV_GENOA'), (NULL, 'MINOR_CIV_VENICE');
INSERT INTO FormableNation_OrganisationMembers (OrganisationType, CivilizationType, MinorCivType)
	SELECT o.Type, e.CivilizationType, e.MinorCivType FROM FN_European e, FormableNation_Organisations o
	WHERE o.Type IN ('ORG_ECSC', 'ORG_EEC', 'ORG_EU')
	AND (e.CivilizationType IN (SELECT Type FROM Civilizations) OR e.MinorCivType IN (SELECT Type FROM MinorCivilizations));
DROP TABLE FN_European;

INSERT INTO FormableNation_OrganisationMembers (OrganisationType, CivilizationType, MinorCivType) VALUES
	-- Hanseatic League: member towns and Kontore (Novgorod's Peterhof, Bergen, Bruges, London's Steelyard)
	('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_GERMANY', NULL), ('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_DENMARK', NULL),
	('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_SWEDEN', NULL), ('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_NETHERLANDS', NULL),
	('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_POLAND', NULL), ('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_ENGLAND', NULL),
	('ORG_HANSEATIC_LEAGUE', 'CIVILIZATION_RUSSIA', NULL),
	('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_NOVGOROD'), ('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_RIGA'),
	('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_STOCKHOLM'), ('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_OSLO'),
	('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_BRUSSELS'), ('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_ANTWERP'),
	('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_BRANDENBURG'), ('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_COPENHAGEN'),
	('ORG_HANSEATIC_LEAGUE', NULL, 'MINOR_CIV_WINCHESTER'),
	-- Arab League (1945)
	('ORG_ARAB_LEAGUE', 'CIVILIZATION_ARABIA', NULL), ('ORG_ARAB_LEAGUE', 'CIVILIZATION_EGYPT', NULL),
	('ORG_ARAB_LEAGUE', 'CIVILIZATION_MOROCCO', NULL),
	('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_SIDON'), ('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_TYRE'),
	('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_BYBLOS'), ('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_MOGADISHU'),
	('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_MARRAKECH'), ('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_RAQMU'),
	('ORG_ARAB_LEAGUE', NULL, 'MINOR_CIV_ORMUS'),
	-- African Union (OAU 1963)
	('ORG_AFRICAN_UNION', 'CIVILIZATION_ETHIOPIA', NULL), ('ORG_AFRICAN_UNION', 'CIVILIZATION_ZULU', NULL),
	('ORG_AFRICAN_UNION', 'CIVILIZATION_SONGHAI', NULL), ('ORG_AFRICAN_UNION', 'CIVILIZATION_MOROCCO', NULL),
	('ORG_AFRICAN_UNION', 'CIVILIZATION_EGYPT', NULL), ('ORG_AFRICAN_UNION', 'CIVILIZATION_CARTHAGE', NULL),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_MOMBASA'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_ZANZIBAR'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_CAPE_TOWN'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_MBANZA_KONGO'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_IFE'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_ANTANANARIVO'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_MOGADISHU'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_KUMASI'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_BORNU'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_SOKOTO'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_OUGADOUGOU'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_SEGOU'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_LUBA'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_BUNKEYA'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_AKSUM'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_DJENNE'),
	('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_KWA_BULAWAYO'), ('ORG_AFRICAN_UNION', NULL, 'MINOR_CIV_MARRAKECH'),
	-- ASEAN (1967)
	('ORG_ASEAN', 'CIVILIZATION_SIAM', NULL), ('ORG_ASEAN', 'CIVILIZATION_INDONESIA', NULL),
	('ORG_ASEAN', NULL, 'MINOR_CIV_HANOI'), ('ORG_ASEAN', NULL, 'MINOR_CIV_MANILA'),
	('ORG_ASEAN', NULL, 'MINOR_CIV_KUALA_LUMPUR'), ('ORG_ASEAN', NULL, 'MINOR_CIV_SINGAPORE'),
	('ORG_ASEAN', NULL, 'MINOR_CIV_MALACCA'), ('ORG_ASEAN', NULL, 'MINOR_CIV_JAKARTA'),
	-- Nordic Council (1952)
	('ORG_NORDIC_COUNCIL', 'CIVILIZATION_DENMARK', NULL), ('ORG_NORDIC_COUNCIL', 'CIVILIZATION_SWEDEN', NULL),
	('ORG_NORDIC_COUNCIL', NULL, 'MINOR_CIV_OSLO'), ('ORG_NORDIC_COUNCIL', NULL, 'MINOR_CIV_HELSINKI'),
	('ORG_NORDIC_COUNCIL', NULL, 'MINOR_CIV_STOCKHOLM'), ('ORG_NORDIC_COUNCIL', NULL, 'MINOR_CIV_COPENHAGEN'),
	-- Mercosur (1991)
	('ORG_MERCOSUR', 'CIVILIZATION_BRAZIL', NULL),
	('ORG_MERCOSUR', NULL, 'MINOR_CIV_BUENOS_AIRES'), ('ORG_MERCOSUR', NULL, 'MINOR_CIV_RIO_DE_JANEIRO'),
	('ORG_MERCOSUR', NULL, 'MINOR_CIV_BOGOTA');

-- v0.5: organisations for civilizations better served by them than by a formation.
INSERT INTO FormableNation_Organisations
	(Type, Depth, Title, Help, Quote, MinEra, MaxEra, MinMembers, TradeRouteGold, MinorInfluence, OpenBorders, FounderCivilization)
VALUES
	('ORG_TRIBUTARY_SYSTEM', 'FUNCTIONAL', 'TXT_KEY_FN_ORG_TRIBUTARY_TITLE', 'TXT_KEY_FN_ORG_TRIBUTARY_HELP', 'TXT_KEY_FN_ORG_TRIBUTARY_QUOTE',
		'ERA_CLASSICAL', 'ERA_INDUSTRIAL', 3, 2, 2, 0, 'CIVILIZATION_CHINA'),
	('ORG_NON_ALIGNED', 'INTERGOVERNMENTAL', 'TXT_KEY_FN_ORG_NON_ALIGNED_TITLE', 'TXT_KEY_FN_ORG_INTERGOV_HELP', 'TXT_KEY_FN_ORG_NON_ALIGNED_QUOTE',
		'ERA_POSTMODERN', NULL, 3, 2, 1, 1, NULL);
INSERT INTO FormableNation_Organisations
	(Type, Depth, Title, Help, Quote, MinEra, MaxEra, MinMembers, OpenBorders, MemberCohesion, NoWarBetweenMembers,
	 Obligation, Scope, NoSeparatePeace, Burden, Hegemonic, Custom)
VALUES
	('ORG_COVENANT_CHAIN', 'ALLIANCE', 'TXT_KEY_FN_ORG_COVENANT_CHAIN_TITLE', NULL, 'TXT_KEY_FN_ORG_COVENANT_CHAIN_QUOTE',
		'ERA_RENAISSANCE', 'ERA_INDUSTRIAL', 2, 0, 1, 1, 'DEFENCE', 'REGIONAL', 0, 'NONE', 0, 0);

CREATE TEMP TABLE FN_MoreMembers (OrganisationType text, CivilizationType text, MinorCivType text);
INSERT INTO FN_MoreMembers VALUES
	-- Tributary system: China at the centre (only China may found it), tributaries around it
	('ORG_TRIBUTARY_SYSTEM', 'CIVILIZATION_CHINA', NULL), ('ORG_TRIBUTARY_SYSTEM', 'CIVILIZATION_KOREA', NULL),
	('ORG_TRIBUTARY_SYSTEM', 'CIVILIZATION_SIAM', NULL), ('ORG_TRIBUTARY_SYSTEM', 'CIVILIZATION_JAPAN', NULL),
	('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_HANOI'), ('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_MALACCA'),
	('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_MANILA'), ('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_SEOUL'),
	('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_COLOMBO'), ('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_KATHMANDU'),
	('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_SAMARKAND'), ('ORG_TRIBUTARY_SYSTEM', NULL, 'MINOR_CIV_YAMATAI'),
	-- Non-Aligned Movement (Belgrade, 1961)
	('ORG_NON_ALIGNED', 'CIVILIZATION_INDIA', NULL), ('ORG_NON_ALIGNED', 'CIVILIZATION_INDONESIA', NULL),
	('ORG_NON_ALIGNED', 'CIVILIZATION_EGYPT', NULL), ('ORG_NON_ALIGNED', 'CIVILIZATION_ETHIOPIA', NULL),
	('ORG_NON_ALIGNED', 'CIVILIZATION_MOROCCO', NULL), ('ORG_NON_ALIGNED', 'CIVILIZATION_SONGHAI', NULL),
	('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_BELGRADE'), ('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_HANOI'),
	('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_COLOMBO'), ('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_KATHMANDU'),
	('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_KABUL'), ('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_JAKARTA'),
	('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_KUMASI'), ('ORG_NON_ALIGNED', NULL, 'MINOR_CIV_MBANZA_KONGO'),
	-- Covenant Chain (1677): the Haudenosaunee and the English colonies
	('ORG_COVENANT_CHAIN', 'CIVILIZATION_IROQUOIS', NULL), ('ORG_COVENANT_CHAIN', 'CIVILIZATION_ENGLAND', NULL),
	('ORG_COVENANT_CHAIN', 'CIVILIZATION_AMERICA', NULL), ('ORG_COVENANT_CHAIN', 'CIVILIZATION_SHOSHONE', NULL),
	('ORG_COVENANT_CHAIN', NULL, 'MINOR_CIV_ONONDAGA'), ('ORG_COVENANT_CHAIN', NULL, 'MINOR_CIV_SALEM'),
	('ORG_COVENANT_CHAIN', NULL, 'MINOR_CIV_CAHOKIA');
INSERT INTO FormableNation_OrganisationMembers (OrganisationType, CivilizationType, MinorCivType)
	SELECT OrganisationType, CivilizationType, MinorCivType FROM FN_MoreMembers
	WHERE CivilizationType IN (SELECT Type FROM Civilizations) OR MinorCivType IN (SELECT Type FROM MinorCivilizations);
DROP TABLE FN_MoreMembers;
