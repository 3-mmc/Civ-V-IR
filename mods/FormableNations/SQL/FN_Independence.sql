-- Formable Nations v0.3: independence and fragmentation data. Logic: UI/FN_Independence.lua.

INSERT INTO FormableNation_EraSettings (Name, EraType) VALUES
	('FOREIGN_INDEPENDENCE', 'ERA_MEDIEVAL'),     -- cities of another people can break away from this era on
	('COLONY_INDEPENDENCE', 'ERA_INDUSTRIAL'),    -- colonies can break away from this era on
	('NATIONALISM', 'ERA_INDUSTRIAL');            -- the nationalism term starts here and grows each era

-- Colonial-era City-States a colony may become. Only types that exist in the database are listed, so the list
-- survives City-State packs that remove some.
INSERT INTO FormableNation_ColonialStates (MinorCivType)
SELECT Type FROM MinorCivilizations WHERE Type IN (
	'MINOR_CIV_QUEBEC_CITY', 'MINOR_CIV_VANCOUVER', 'MINOR_CIV_SYDNEY', 'MINOR_CIV_MELBOURNE', 'MINOR_CIV_WELLINGTON',
	'MINOR_CIV_CAPE_TOWN', 'MINOR_CIV_BUENOS_AIRES', 'MINOR_CIV_BOGOTA', 'MINOR_CIV_PANAMA_CITY', 'MINOR_CIV_RIO_DE_JANEIRO',
	'MINOR_CIV_HONG_KONG', 'MINOR_CIV_SINGAPORE', 'MINOR_CIV_MANILA', 'MINOR_CIV_MALACCA', 'MINOR_CIV_COLOMBO',
	'MINOR_CIV_KUALA_LUMPUR', 'MINOR_CIV_ZANZIBAR', 'MINOR_CIV_MOMBASA', 'MINOR_CIV_VALLETTA', 'MINOR_CIV_JAKARTA');
