-- Formable Nations tuning. Turn values are for Standard speed and are scaled by game speed at runtime.
-- Cohesion values are 0-100. See docs/formable-nations-design.md, "Cohesion and secession".
CREATE TABLE IF NOT EXISTS FormableNation_Settings (
	Name text NOT NULL UNIQUE,
	Value integer NOT NULL
);

INSERT INTO FormableNation_Settings (Name, Value) VALUES
	('UNION_ALLIED_TURNS', 15),        -- alliance length before a City-State can enter a union
	('RESTING_ABOVE_ALLY', 10),        -- union partners' Influence resting point: alliance threshold + this
	('COHESION_START', 60),
	('COHESION_DRIFT', 2),             -- points per turn toward equilibrium
	('COHESION_BASE', 50),
	('COHESION_FLOOR_NO_CAUSE', 40),   -- with no negative factor active, equilibrium never falls below this
	('COHESION_INTEGRATED', 75),       -- deepening to a State stage needs every partner at or above this...
	('COHESION_CRISIS', 40),           -- below this: autonomy crisis
	('COHESION_SECESSION', 20),        -- below this: secession countdown
	('SECESSION_COUNTDOWN', 5),
	('CRISIS_COOLDOWN', 30),
	('CRISIS_EXPIRES', 10),            -- an unanswered crisis lapses after this many turns
	('CONCEDE_GOLD_PER_ERA', 40),      -- one-off cost: this x (era + 1), scaled by game speed
	('CONCEDE_BONUS', 15), ('CONCEDE_TURNS', 20),
	('PRIVILEGE_GOLD_PER_ERA', 2),     -- per-turn tribute: this x (era + 1)
	('PRIVILEGE_BONUS', 10), ('PRIVILEGE_TURNS', 30),
	('ASSERT_INFLUENCE_COST', 10),     -- Influence lost with every other City-State
	('ASSERT_BONUS', 20), ('ASSERT_TURNS', 10),
	-- Equilibrium terms
	('TERM_LEAD_MAX', 15), ('TERM_LEAD_DIVISOR', 5), ('TERM_CONTESTED', -25),
	('TERM_RELIGION_SHARED', 10), ('TERM_RELIGION_DIFFERENT', -5),
	('TERM_TRADE', 8), ('TERM_NEIGHBOURS', 5), ('NEIGHBOUR_DISTANCE', 6),
	('TERM_TENURE_PER_10', 1), ('TERM_TENURE_MAX', 10),
	('TERM_WAR_EACH', -5), ('TERM_WAR_MAX', -15),
	('TERM_UNHAPPY', -10),
	('TERM_STRONGER_VASSAL', -15),

	-- Independence and fragmentation: local cohesion of cities that are not integrated (colonies abroad, cities of
	-- another people). See the design doc, "Independence and fragmentation".
	('CITY_START', 50),
	('CITY_DRIFT', 1),                 -- points per turn toward equilibrium (slower than union bonds)
	('CITY_BASE', 50),
	('CITY_FLOOR_NO_CAUSE', 40),
	('CITY_INTEGRATED', 75),           -- at or above this for CITY_INTEGRATION_TURNS, a city integrates for good
	('CITY_INTEGRATION_TURNS', 30),
	('CITY_MOVEMENT', 35),             -- below this: an independence movement (responses become available)
	('CITY_SECESSION', 20),            -- below this: breakaway countdown
	('CITY_COUNTDOWN', 8),
	('MOVEMENT_COOLDOWN', 20),         -- after a response, no new movement in that city for this long
	('BREAKAWAY_COOLDOWN', 20),        -- at most one breakaway per player per this many turns
	('COLONY_MIN_DISTANCE', 12),       -- a city on another landmass at least this far from the capital is a colony
	('AUTONOMY_GOLD_PER_ERA', 30), ('AUTONOMY_BONUS', 15), ('AUTONOMY_TURNS', 20),
	('SUPPRESS_BONUS', 20), ('SUPPRESS_TURNS', 10), ('SUPPRESS_RESISTANCE', 3),
	('RELEASE_INFLUENCE', 50),         -- a city released peacefully starts this friendly with its former ruler
	('BREAKAWAY_INFLUENCE', -30),      -- ...and this hostile after a secession
	('FRAGMENT_RADIUS', 6),            -- restless cities this close to a breakaway city go with it
	('FRAGMENT_MAX_EXTRA', 2),
	('REVIVAL_UNITS', 2),              -- defenders for a revived civilization
	('RENAME_BREAKAWAY', 0),           -- 0: a seceding city keeps its own name; 1: it takes its new City-State's name when none matches
	-- Local equilibrium terms
	('TERM_CONNECTED', 5), ('TERM_NOT_CONNECTED', -5),
	('TERM_CITY_RELIGION_SHARED', 10), ('TERM_CITY_RELIGION_DIFFERENT', -10),
	('TERM_GARRISON', 5), ('TERM_PUPPET', 5),
	('TERM_CITY_TENURE_PER_10', 1), ('TERM_CITY_TENURE_MAX', 15),
	('DISTANCE_STEP', 5), ('TERM_DISTANCE_MAX', -10),
	('TERM_FOREIGN_ALIVE', -10), ('TERM_FOREIGN_DEAD', -5), ('TERM_FOREIGN_MINOR', -5),
	('TERM_NATIONALISM_PER_ERA', -5), ('TERM_NATIONALISM_MAX', -15),
	('TERM_CITY_UNHAPPY', -10), ('TERM_CITY_VERY_UNHAPPY', -15), ('TERM_CITY_SUPER_UNHAPPY', -20),
	('TERM_CIVIL_RESISTANCE', -10), ('TERM_REVOLUTIONARY_WAVE', -20),

	-- Historical City-States at game start (UI/FN_Setup.lua)
	('HISTORICAL_CITY_STATES', 1),     -- 1: swap in the City-States the civs in this game need for their formations
	('HISTORICAL_MAX_PERCENT', 50),    -- at most this share of the game's City-States is replaced
	('HISTORICAL_TRAIT_PREFERENCE', 8),-- prefer replacing a City-State of the same trait if it is within this many tiles
	('HISTORICAL_WAIT_TURNS', 3),      -- wait at most this long for every City-State to found its city

	-- Supranational organisations: members' cohesion with the organisation (UI/FN_Organisations.lua)
	('ORG_COHESION_START', 60),
	('ORG_EXIT_THRESHOLD', 25),        -- below this: an exit referendum, decided after ORG_EXIT_COUNTDOWN turns
	('ORG_EXIT_COUNTDOWN', 5),
	('OPTOUT_GOLD_PER_ERA', 40), ('OPTOUT_BONUS', 15), ('OPTOUT_TURNS', 20),
	('TERM_ORG_IDEOLOGY_SHARED', 10), ('TERM_ORG_IDEOLOGY_RIVAL', -15),
	('TERM_ORG_TRADE', 8), ('TERM_ORG_FRIENDS', 5), ('TERM_ORG_DENOUNCE', -10), ('TERM_ORG_FOUNDER', 5),

	-- Alliances (UI/FN_Alliances.lua)
	('ALLIANCE_REGION_TILES', 30),     -- REGIONAL scope: the aggressor's capital within this many tiles of the attacked member's
	('ALLIANCE_CALL_TURNS', 5),        -- a human's unanswered call to arms counts as declined after this long
	('ALLIANCE_AI_HONOUR', 40),        -- an AI member honours a call to arms at this cohesion or above
	('CREDIT_HONOUR', 10), ('CREDIT_DECLINE', -15), -- credibility for answering a binding call; it fades by 1 a turn
	('TERM_CREDIT_MAX', 10), ('TERM_CREDIT_MIN', -20),
	('THREAT_TILES', 25), ('TERM_THREAT', 10), -- a stronger outside power this close to a member binds the alliance together
	('BURDEN_TARGET_PERCENT', 50),     -- TARGET: military might at least this share of the members' average
	('TERM_TARGET_MET', 5), ('TERM_TARGET_MISSED', -10),
	('TRIBUTE_GOLD_PER_ERA', 1), ('TERM_TRIBUTE', -5); -- TRIBUTE: per turn per member, x (era + 1), paid to the leader
