-- Offline harness: runs the real Formable Nations modules against a mock of the Civ V Lua API.
-- Usage: python3 tests/make_gameinfo.py && lua5.1 tests/harness.lua   (from the mod root)
-- It catches runtime errors and checks the scripted outcomes below; balance still needs real games.
package.path = "./?.lua;" .. package.path
dofile("tests/gameinfo_data.lua")

local function Stub()
	local s = {}
	return setmetatable(s, { __index = function() return function() return Stub() end end })
end

-- GameInfo -------------------------------------------------------------------
GameInfo, GameInfoTypes = {}, {}
for sTable, tRows in pairs(GI_DATA) do
	local byKey = {}
	for _, row in ipairs(tRows) do
		if row.ID then byKey[row.ID] = row end
		if row.Type then byKey[row.Type] = row; if row.ID then GameInfoTypes[row.Type] = row.ID end end
	end
	GameInfo[sTable] = setmetatable(byKey, { __call = function()
		local i = 0
		return function() i = i + 1; return tRows[i] end
	end })
end
GameDefines = { MAX_MAJOR_CIVS = 22, MAX_CIV_PLAYERS = 63, FRIENDSHIP_THRESHOLD_ALLIES = 60, FRIENDSHIP_THRESHOLD_FRIENDS = 30 }
-- Text keys come back as "KEY|arg|arg", except City-State names, which read like the game's ("TXT_KEY_CITYSTATE_QUEBEC_CITY" -> "Quebec City").
local function TitleCase(s) return (s:lower():gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)) end
Locale = { ConvertTextKey = function(k, ...)
	if select("#", ...) == 0 and type(k) == "string" and k:find("^TXT_KEY_CITYSTATE_") then return TitleCase(k:sub(19)) end
	local t = { tostring(k) } for _, v in ipairs({ ... }) do t[#t + 1] = tostring(v) end return table.concat(t, "|")
end }
NotificationTypes = { NOTIFICATION_GENERIC = 1 }
Mouse, Keys, KeyEvents = { eLClick = 1 }, { VK_ESCAPE = 27 }, { KeyDown = 256 }
function Vector2(x, y) return { x = x, y = y } end
function Vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
function ToHexFromGrid(v) return v end

local SAVE = {}
Modding = { OpenSaveData = function() return { GetValue = function(k) return SAVE[k] end, SetValue = function(k, v) SAVE[k] = v end } end }
local PREGAME = {}
PreGame = setmetatable({}, { __index = function(_, k)
	if k:find("^Set") then return function(p, v) PREGAME[k:sub(4) .. p] = v end end
	return function(p) return PREGAME[k:sub(4) .. p] end
end })

local function Hooks() local h = {} return setmetatable(h, { __index = { Add = function(fn) table.insert(h, fn) end } }) end
GameEvents = { PlayerDoTurn = Hooks(), CityCaptureComplete = Hooks(), PlayerCanDeclareWar = Hooks(), DeclareWar = Hooks(), PlayerCanMakePeace = Hooks() }
Events = setmetatable({}, { __index = function(t, k)
	if k == "SerialEventHexHighlight" or k == "ClearHexHighlightStyle" then return function() end end
	local h = Hooks(); rawset(t, k, h); return h
end })
LuaEvents = { AdditionalInformationDropdownGatherEntries = Hooks(), RequestRefreshAdditionalInformationDropdownEntries = function() end }
local DROPDOWN = {}
ContextPtr = { SetInputHandler = function() end, SetHide = function() end, IsHidden = function() return true end }
Controls = setmetatable({}, { __index = function() return Stub() end })
InstanceManager = { new = function() return { GetInstance = function() return setmetatable({}, { __index = function() return Stub() end }) end, ResetInstances = function() end } end }
function include(sName)
	if sName == "InstanceManager" or sName == "FLuaVector" then return end
	dofile("UI/" .. sName .. ".lua")
end

-- World ----------------------------------------------------------------------
local TURN = 1
local PLOTS = {}
Map = {
	PlotDistance = function(x1, y1, x2, y2) return math.max(math.abs(x1 - x2), math.abs(y1 - y2)) end,
	GetNumPlots = function() return #PLOTS end,
	GetPlotByIndex = function(i) return PLOTS[i + 1] end,
	GetPlot = function(x, y) for _, pl in ipairs(PLOTS) do if pl.GetX() == x and pl.GetY() == y then return pl end end end,
}
Players, Teams = {}, {}
Game = {
	GetGameTurn = function() return TURN end, GetGameSpeedType = function() return GameInfoTypes.GAMESPEED_STANDARD end,
	GetActivePlayer = function() return 0 end, GetActiveTeam = function() return 0 end,
	GetElapsedGameTurns = function() return TURN - 1 end,
	Rand = function(n) return 0 end,
	ChangeMinorPlayer = function(slot, iType) Players[slot].minor = iType end,
	-- As CvGame::CreateFreeCityPlayer: a dead City-State that once owned the city, else the first never-used slot.
	DoSpawnFreeCity = function(c)
		local slot
		for i = 22, 62 do local p = Players[i]; if p and not p.alive and c.owners[i] then slot = i break end end
		if not slot then for i = 22, 62 do local p = Players[i]; if p and not p.everAlive then slot = i break end end end
		if not slot then return end
		local p = Players[slot]
		local old = Players[c.owner]
		p.alive, p.everAlive = true, true
		p:AcquireCity(c, false, false)
		p.origCap = c
		if old.minor then -- replacing a City-State: the engine retires it and hands out the starting Settler
			old.alive, old.units = false, {}
			p:AddUnit({ found = true })
		end
	end,
}

local NOTES = {}
local Player, Team, City = {}, {}, {}
Player.__index, Team.__index, City.__index = Player, Team, City

local function NewCity(owner, x, y, name)
	local c = setmetatable({ owner = owner, x = x, y = y, religion = -1, coastal = true, name = name or ("City" .. (#PLOTS + 1)),
		origOwner = owner, founded = TURN, acquired = TURN, owners = { [owner] = true }, area = 1, connected = true, resistance = 0 }, City)
	local iIndex = #PLOTS
	c.plot = { GetPlotCity = function() return c end, GetOwner = function() return c.owner end,
		GetX = function() return x end, GetY = function() return y end, IsRevealed = function() return true end,
		GetPlotIndex = function() return iIndex end, GetArea = function() return c.area end }
	table.insert(PLOTS, c.plot)
	return c
end
function City:Plot() return self.plot end
function City:GetName() return self.name end
function City:SetName(s) self.name = s end
function City:IsCapital() return Players[self.owner]:GetCapitalCity() == self end
function City:GetOriginalOwner() return self.origOwner end
function City:GetGameTurnFounded() return self.founded end
function City:GetGameTurnAcquired() return self.acquired end
function City:GetGarrisonedUnit() return self.garrison and {} or nil end
function City:IsPuppet() return self.puppet == true end
function City:GetNumTimesOwned(i) return self.owners[i] and 1 or 0 end
function City:ChangeResistanceTurns(n) self.resistance = self.resistance + n end
function City:CanTrain() return true end
function City:GetOwner() return self.owner end
function City:GetX() return self.x end
function City:GetY() return self.y end
function City:GetReligiousMajority() return self.religion end
function City:IsCoastal() return self.coastal end

local function NewPlayer(id, t)
	local p = setmetatable(t, Player)
	p.id, p.alive, p.everAlive = id, true, true
	p.policies, p.influence, p.resting, p.cities, p.units = {}, {}, {}, {}, {}
	p.gold, p.era, p.routes, p.resources, p.married, p.might = p.gold or 0, p.era or 0, {}, {}, {}, p.might or 10
	p.alliedTurns, p.ally = 0, -1
	Players[id] = p
	Teams[id] = setmetatable({ id = id, war = {}, vassalOf = -1, met = {}, openBorders = {} }, Team)
	return p
end
function Player:GetID() return self.id end
function Player:GetTeam() return self.id end
function Player:IsAlive() return self.alive end
function Player:IsEverAlive() return self.everAlive end
function Player:IsMinorCiv() return self.minor ~= nil end
function Player:IsHuman() return self.human == true end
function Player:IsBarbarian() return false end
function Player:GetMinorCivType() return self.minor end
function Player:GetCivilizationType() return self.civ or -1 end
function Player:GetOriginalCapitalPlot() return self.origCap and self.origCap.plot end
function Player:GetCapitalCity() for _, c in ipairs(self.cities) do return c end end
function Player:HasPolicy(i) return self.policies[i] == true end
function Player:SetHasPolicy(i, b) self.policies[i] = b and true or nil end
function Player:GetCurrentEra() return self.era end
function Player:IsEmpireUnhappy() return self.unhappy == true end
function Player:GetGold() return self.gold end
function Player:ChangeGold(n) self.gold = self.gold + n end
function Player:GetBuyoutCost() return 500 end
function Player:IsMarried(m) return self.married[m] == true end
function Player:GetMinorCivFriendshipWithMajor(m) return self.influence[m] or 0 end
function Player:ChangeMinorCivFriendshipWithMajor(m, n) self.influence[m] = (self.influence[m] or 0) + n end
function Player:GetMinorCivFriendshipAnchorWithMajor(m) return 0 end
function Player:ChangeRestingPointChange(m, n) self.resting[m] = (self.resting[m] or 0) + n end
function Player:IsAllies(m) return self.ally == m end
function Player:IsFriends(m) return (self.influence[m] or 0) >= 30 end
function Player:GetAlliedTurns() return self.alliedTurns end
function Player:Units() local i = 0 return function() i = i + 1; return self.units[i] end end
function Player:Cities() local i = 0 local t = { unpack(self.cities) } return function() i = i + 1; return t[i] end end
function Player:AcquireCity(c, bConquest)
	local old = Players[c.owner]
	for i, x in ipairs(old.cities) do if x == c then table.remove(old.cities, i) end end
	if #old.cities == 0 then old.alive = false end
	c.owner, c.acquired, c.owners[self.id] = self.id, TURN, true
	table.insert(self.cities, c)
	self.alive = true -- the engine's verifyAlive revives a dead player that owns a city
	for _, fn in ipairs(GameEvents.CityCaptureComplete) do fn(old.id, false, c.x, c.y, self.id, 1, bConquest == true) end
end
function Player:InitUnit(iType, x, y)
	self.spawned = self.spawned or {}; table.insert(self.spawned, iType)
	return self:AddUnit({ type = iType, x = x, y = y, combat = true, FinishMoves = function() end })
end
function Player:IsCapitalConnectedToCity(c) return c.connected end
function Player:IsEmpireVeryUnhappy() return self.veryUnhappy == true end
function Player:IsEmpireSuperUnhappy() return false end
function Player:GetPublicOpinionType() return self.opinion or 0 end
function Player:ChangeGoldenAgeTurns(n) self.goldenAge = (self.goldenAge or 0) + n end
function Player:IsObserver() return false end
function Player:GetName() return self.name or ("P" .. self.id) end
function Player:GetCivilizationShortDescriptionKey() return "CIV" .. self.id end
function Player:AddNotification(_, sText) table.insert(NOTES, sText) end
function Player:IsTurnActive() return true end
function Player:GetVassalTreatmentLevel() return 0 end
function Player:GetMilitaryMight() return self.might end
function Player:GetStateReligion() return self.stateReligion or -1 end
function Player:GetTradeRoutes() return self.routes end
function Player:GetNumResourceTotal(r) return self.resources[r] or 0 end
function Player:IsDenouncingPlayer(i) return self.denouncing ~= nil and self.denouncing[i] == true end
function Player:GetLateGamePolicyTree() return self.ideology or -1 end
function Player:IsDoF() return false end
function Player:GetStartingPlot() return self.origCap and self.origCap.plot end
local Unit = {}
Unit.__index = Unit
function Player:AddUnit(t) t.owner = self; table.insert(self.units, setmetatable(t, Unit)); return t end
function Unit:IsFound() return self.found == true end
function Unit:IsCombatUnit() return self.combat == true end
function Unit:GetUnitType() return self.type or 0 end
function Unit:GetX() return self.x or 0 end
function Unit:GetY() return self.y or 0 end
function Unit:Kill() for i, u in ipairs(self.owner.units) do if u == self then table.remove(self.owner.units, i) end end end
function Player:GetPlayerColors() return { x = 1, y = 0, z = 0, w = 1 }, { x = 1, y = 1, z = 1, w = 1 } end
function Team:IsAtWar(t) return self.war[t] == true end
function Team:IsVassal(t) return self.vassalOf == t end
function Team:IsHasMet() return true end
function Team:GetAtWarCount() local n = 0 for _, b in pairs(self.war) do if b then n = n + 1 end end return n end
function Team:DoEndVassal(t) Teams[t].vassalOf = -1 end
function Team:SetOpenBorders(t, b) self.openBorders[t] = b end
function Team:CanDeclareWar(t)
	for _, fn in ipairs(GameEvents.PlayerCanDeclareWar) do if fn(self.id, t) == false then return false end end
	return true
end
-- As CvTeam::DoDeclareWar: the DeclareWar event fires, then both sides are at war.
function Team:DeclareWar(t, bDefensivePact, iPlayer)
	for _, fn in ipairs(GameEvents.DeclareWar) do fn(iPlayer or self.id, t, true) end
	self.war[t], Teams[t].war[self.id] = true, true
end
local function CanMakePeace(iPlayer, iTeam)
	for _, fn in ipairs(GameEvents.PlayerCanMakePeace) do if fn(iPlayer, iTeam) == false then return false end end
	return true
end

-- Minor-civ simulation: influence decays toward the resting point by 1 per turn; ally = top influence >= 60.
local function TickMinors()
	for id = 22, 62 do
		local p = Players[id]
		if p and p.alive then
			for m, v in pairs(p.influence) do
				local rest = p.resting[m] or 0
				if v > rest then p.influence[m] = v - 1 elseif v < rest then p.influence[m] = v + 1 end
			end
			local best, bestV = -1, 59
			for m, v in pairs(p.influence) do if v > bestV then best, bestV = m, v end end
			if best ~= p.ally then p.ally, p.alliedTurns = best, 0 elseif best >= 0 then p.alliedTurns = p.alliedTurns + 1 end
		end
	end
end

local function RunTurns(n)
	for _ = 1, n do
		TURN = TURN + 1
		TickMinors()
		for id = 0, 21 do
			if Players[id] and Players[id].alive then
				for _, fn in ipairs(GameEvents.PlayerDoTurn) do fn(id) end
			end
		end
	end
end

-- Setup ----------------------------------------------------------------------
local CIV = function(s) return GameInfoTypes["CIVILIZATION_" .. s] end
local MINOR = function(s) return GameInfoTypes["MINOR_CIV_" .. s] end
local POLICY = function(s) return GameInfoTypes["POLICY_FN_" .. s] end

local poland = NewPlayer(0, { civ = CIV("POLAND"), name = "Jadwiga", era = 2, gold = 2000 })
poland.cities[1] = NewCity(0, 10, 10); poland.origCap = poland.cities[1]
local rival = NewPlayer(1, { civ = CIV("RUSSIA"), name = "Rival", era = 2 })
rival.cities[1] = NewCity(1, 40, 40); rival.origCap = rival.cities[1]
local arabia = NewPlayer(2, { civ = CIV("ARABIA"), name = "Harun", era = 6 })
arabia.cities[1] = NewCity(2, 60, 10); arabia.origCap = arabia.cities[1]
local persia = NewPlayer(3, { civ = CIV("PERSIA"), name = "Darius", era = 6 })
persia.cities[1] = NewCity(3, 70, 10); persia.origCap = persia.cities[1]
local vilnius = NewPlayer(22, { minor = MINOR("VILNIUS") })
vilnius.cities[1] = NewCity(22, 14, 10); vilnius.origCap = vilnius.cities[1]
local oilRes = GameInfoTypes.RESOURCE_OIL

-- Germany, whose Holy Roman Empire partners are all missing, and City-States that could make way for them.
-- Unused City-State slots, as VP leaves them: never alive, with a placeholder type.
local germany = NewPlayer(5, { civ = CIV("GERMANY"), name = "Otto", era = 0 })
germany.cities[1] = NewCity(5, 200, 10, "Aachen"); germany.origCap = germany.cities[1]
local DONORS = {}
for i, sType in ipairs({ "KABUL", "ALMATY", "MOGADISHU", "KYZYL", "ANTANANARIVO", "LA_VENTA" }) do
	local d = NewPlayer(23 + i, { minor = MINOR(sType) })
	d.cities[1] = NewCity(23 + i, 200 + i * 3, 20, "CS" .. i); d.origCap = d.cities[1]
	d:AddUnit({ combat = true, type = 7, x = 200 + i * 3, y = 21 })
	DONORS[i] = d
end
for id = 30, 40 do local p = NewPlayer(id, { minor = 0 }); p.alive, p.everAlive = false, false end

dofile("UI/FormableNations.lua")

local FAILS = 0
local function Check(b, sWhat)
	print((b and "  ok   " or "  FAIL ") .. sWhat)
	if not b then FAILS = FAILS + 1 end
end
local function C() return FN.GetCohesion(0, 22) end

print("Scenario 0: historical City-States are swapped in at game start")
RunTurns(1)
local function Present(sType) for i = 22, 62 do local p = Players[i] if p and p.alive and p.minor == MINOR(sType) then return p end end end
local vatican, wittenberg, prague = Present("VATICAN_CITY"), Present("WITTENBERG"), Present("PRAGUE")
Check(vatican and wittenberg and prague, "Vatican City, Wittenberg and Prague now exist (the HRE needs 1 + 2, the German Empire Wittenberg)")
Check(not DONORS[1].alive and not DONORS[2].alive and not DONORS[3].alive and DONORS[4].alive,
	"the three City-States nearest Germany made way; the rest stay")
Check(vatican and vatican.cities[1].name == "Vatican City", "the city takes its new City-State's name")
Check(vatican and #vatican.units == 1 and not vatican.units[1].found, "the starting Settler is removed and the garrison carried over")
Check(Present("VILNIUS") and FN.GetN("SETUP_DONE") > 0, "Vilnius was already there; setup ran once")
local savedTurn = TURN
TURN = 20; FN.Set("SETUP_DONE", 0); FN.SetupHistoricalCityStates()
Check(DONORS[4].alive and FN.GetN("SETUP_DONE") == 1, "a game already under way (or an older save) is left alone")
TURN = savedTurn

print("Scenario 1: Union of Krewo forms after a long alliance")
vilnius.influence[0] = 90
RunTurns(17)
Check(poland:HasPolicy(POLICY("KREWO")), "AI Poland proclaimed the Union of Krewo")
Check(FN.IsBound(0, 22), "Vilnius is bound")
Check(vilnius.resting[0] == 70, "Vilnius resting point raised to alliance threshold + 10")

print("Scenario 2: shared religion and trade lift cohesion; deepening needs integration")
poland.stateReligion, vilnius.cities[1].religion = 1, 1
poland.routes = { { ToID = 22 } }
poland.era = 3
RunTurns(12)
Check(C() >= 75, string.format("cohesion integrated (%.1f)", C()))
Check(not poland:HasPolicy(POLICY("COMMONWEALTH")), "Commonwealth not yet: integration must last 10 turns")
RunTurns(12)
Check(poland:HasPolicy(POLICY("COMMONWEALTH")), "Commonwealth proclaimed")
Check(not poland:HasPolicy(POLICY("KREWO")), "Krewo superseded")
Check(vilnius.cities[1] == nil and poland.cities[2] ~= nil, "Vilnius annexed peacefully")
Check(PREGAME["CivilizationDescription0"] == "TXT_KEY_FN_COMMONWEALTH_DESC", "Poland renamed")
Check(poland.gold < 2000, "annexation paid")

print("Scenario 3: a contested union falls into crisis and secedes")
-- Fresh union with a second Lithuania stand-in: reset Poland and Vilnius.
SAVE = {}; poland.policies = {}; PREGAME = {}
vilnius.alive, vilnius.cities = true, { vilnius.origCap }; vilnius.origCap.owner = 22
table.remove(poland.cities, 2)
poland.era, poland.routes, poland.stateReligion, vilnius.cities[1].religion = 2, {}, 2, 1 -- different religions
vilnius.influence = { [0] = 90 }; vilnius.resting = {}; vilnius.ally, vilnius.alliedTurns = -1, 0
RunTurns(17)
Check(FN.IsBound(0, 22), "union re-formed")
Teams[0].war[5] = true; Teams[0].war[6] = true; poland.unhappy = true -- wars + unhappiness...
RunTurns(15)
Check(FN.IsBound(0, 22), "wars and unhappiness alone do not break a union with a strong Influence lead")
vilnius.influence[1], vilnius.resting[1] = 140, 140 -- ...and a rival wins Vilnius over (the decisive cause)
local tCrisis, tSecede = nil, nil
for i = 1, 40 do
	RunTurns(1)
	if not tCrisis and FN.GetN("BCD_0_22") > 0 then tCrisis = i end
	if not FN.IsBound(0, 22) then tSecede = i; break end
end
Check(tCrisis ~= nil, "a crisis opened and the AI answered it (turn " .. tostring(tCrisis) .. ")")
Check(tSecede ~= nil, "Vilnius seceded under sustained pressure (turn " .. tostring(tSecede) .. ")")
Check(not poland:HasPolicy(POLICY("KREWO")), "the union dissolved with its only partner gone")

print("Scenario 4: no active cause, no secession")
Teams[0].war = {}; poland.unhappy = false; poland.stateReligion = 1
vilnius.influence = { [0] = 90 }; vilnius.ally, vilnius.alliedTurns = -1, 0
RunTurns(18)
Check(FN.IsBound(0, 22), "union formed again")
RunTurns(60)
Check(FN.IsBound(0, 22) and C() >= 40, string.format("neglected but unthreatened union holds (cohesion %.1f)", C()))

print("Scenario 5: OPEC")
arabia.resources[oilRes], persia.resources[oilRes] = 5, 3
local opecMinor = NewPlayer(23, { minor = MINOR("ORMUS") })
opecMinor.cities[1] = NewCity(23, 62, 12); opecMinor.origCap = opecMinor.cities[1]
opecMinor.resources[oilRes] = 2; opecMinor.influence[2] = 40
local goldBefore = arabia.gold
RunTurns(2)
local opec = FN.OrgByType.ORG_OPEC
Check(FN.OrgActive(opec), "OPEC founded by an AI")
Check(FN.IsMember(opec, 3) and FN.IsMember(opec, 23), "Persia and an oil City-State joined")
Check(arabia.gold > goldBefore, "members earn oil income")
persia.resources[oilRes] = 0
RunTurns(1)
Check(not FN.IsMember(opec, 3), "Persia left once its oil ran out")

print("Scenario 6: perks of a formed state")
local commonwealth = FN.StageByType.FN_COMMONWEALTH
Check(#commonwealth.UniqueUnits == 1 and commonwealth.UniqueUnits[1].Unit == GameInfoTypes.UNIT_FN_HAIDUK
	and commonwealth.UniqueUnits[1].Replaces == GameInfoTypes.UNIT_MUSKETMAN, "the Commonwealth's Haiduk replaces the Musketman")
Check(#FN.StageByType.FN_KREWO.UniqueUnits == 0, "a Tier I union has no unique unit")
Check(poland.goldenAge == 8, "proclaiming the Commonwealth started an 8-turn golden age (" .. tostring(poland.goldenAge) .. ")")

local function BreakawayWithin(c, n)
	local iOwner = c.owner
	for i = 1, n do
		RunTurns(1)
		if c.owner ~= iOwner then return i end
	end
end

print("Scenario 7: a restless colony declares independence under its own name")
local britain = NewPlayer(4, { civ = CIV("ENGLAND"), name = "Victoria", era = 5, stateReligion = 1 })
britain.cities[1] = NewCity(4, 100, 10, "London"); britain.origCap = britain.cities[1]
local sydney = NewCity(4, 140, 50, "Sydney"); sydney.area, sydney.connected, sydney.religion = 2, false, 2
table.insert(britain.cities, sydney)
britain.unhappy = true
local tSydney = BreakawayWithin(sydney, 60)
Check(FN.CityKind(britain.cities[1]) == "CORE", "the capital is core")
Check(tSydney ~= nil, "Sydney broke away (turn " .. tostring(tSydney) .. ")")
local pSydney = Players[sydney.owner]
Check(pSydney:IsMinorCiv() and pSydney.minor == MINOR("SYDNEY"), "as the City-State of Sydney")
Check(sydney.name == "Sydney" and pSydney.origCap == sydney, "keeping its name, as the City-State's capital")
Check(pSydney.influence[4] == -30, "and resenting its former ruler (" .. tostring(pSydney.influence[4]) .. ")")

print("Scenario 8: fragmentation - two neighbouring colonies leave together as a colonial City-State, keeping their names")
local portRoyal = NewCity(4, 150, 60, "Port Royal"); portRoyal.area, portRoyal.connected, portRoyal.religion = 3, false, 2
local kingston = NewCity(4, 153, 62, "Kingston"); kingston.area, kingston.connected, kingston.religion = 3, false, 2
table.insert(britain.cities, portRoyal); table.insert(britain.cities, kingston)
local tPort = BreakawayWithin(portRoyal, 60)
Check(tPort ~= nil, "Port Royal broke away (turn " .. tostring(tPort) .. ")")
Check(kingston.owner == portRoyal.owner, "Kingston went with it")
local iNewType, bColonial = Players[portRoyal.owner].minor, false
for row in GameInfo.FormableNation_ColonialStates() do if GameInfoTypes[row.MinorCivType] == iNewType then bColonial = true end end
Check(bColonial, "as a colonial City-State type (" .. Locale.ConvertTextKey(GameInfo.MinorCivilizations[iNewType].Description) .. ")")
Check(portRoyal.name == "Port Royal" and kingston.name == "Kingston", "the cities keep their own names")

print("Scenario 9: national revival - a conquered people restores its fallen nation")
local celts = NewPlayer(6, { civ = CIV("CELTS"), name = "Boudicca" })
local dun = NewCity(6, 104, 12, "Dun Eideann"); celts.origCap = dun
celts.cities[1] = dun
britain:AcquireCity(dun, true) -- conquest: the Celts are gone
Check(not celts.alive, "the Celts were conquered")
britain.opinion = 3 -- revolutionary wave at home
Check(FN.CityKind(dun) == "FOREIGN", "the Celtic city counts as another people")
local tDun = BreakawayWithin(dun, 60)
Check(tDun ~= nil and dun.owner == 6 and celts.alive, "the Celts are reborn in " .. dun.name .. " (turn " .. tostring(tDun) .. ")")
Check(celts.spawned and #celts.spawned == 2, "with defenders")
britain.opinion, britain.unhappy = 0, false

print("Scenario 10: a human ruler answers movements")
britain.human, britain.gold = true, 1000
local hk = NewCity(4, 170, 20, "Victoria Harbour"); hk.area, hk.connected, hk.religion = 4, false, 2
local goa = NewCity(4, 175, 30, "Goa"); goa.area, goa.connected, goa.religion = 5, false, 2
table.insert(britain.cities, hk); table.insert(britain.cities, goa)
britain.veryUnhappy = true
for _ = 1, 40 do RunTurns(1); if FN.InMovement(hk) and FN.InMovement(goa) then break end end
Check(FN.InMovement(hk) and FN.InMovement(goa), "independence movements formed")
Check(not FN.RespondMovement(britain, hk, "SUPPRESS"), "suppression needs a garrison")
Check(FN.RespondMovement(britain, hk, "AUTONOMY") and not FN.InMovement(hk) and britain.gold < 1000, "autonomy paid for and granted")
Check(FN.RespondMovement(britain, goa, "RELEASE"), "independence granted")
Check(Players[goa.owner]:IsMinorCiv() and Players[goa.owner].influence[4] == 50, "the released city starts friendly (" .. tostring(Players[goa.owner].influence[4]) .. ")")
britain.veryUnhappy, britain.human = false, false

print("Scenario 11: a contented colony integrates and stops counting as a colony")
local quebec = NewCity(0, 60, 60, "Gdansk Nowy"); quebec.area, quebec.religion, quebec.garrison = 9, 1, true
quebec.founded = TURN - 200
table.insert(poland.cities, quebec)
poland.stateReligion = 1
Check(FN.CityKind(quebec) == "COLONY", "a colony across the sea")
RunTurns(60)
Check(FN.CityKind(quebec) == "INTEGRATED", "integrated after holding high cohesion (" .. FN.CityKind(quebec) .. ")")

print("Scenario 12: the European chain - Coal and Steel, Economic Community, Union, and an exit")
local france = NewPlayer(7, { civ = CIV("FRANCE"), name = "Napoleon", era = 5, ideology = 1 })
france.cities[1] = NewCity(7, 300, 10, "Paris"); france.origCap = france.cities[1]
local dutch = NewPlayer(8, { civ = CIV("NETHERLANDS"), name = "William", era = 5, ideology = 1 })
dutch.cities[1] = NewCity(8, 305, 14, "Amsterdam"); dutch.origCap = dutch.cities[1]
local italy = NewPlayer(9, { civ = CIV("ROME"), name = "Augustus", era = 5, ideology = 1 })
italy.cities[1] = NewCity(9, 310, 30, "Rome"); italy.origCap = italy.cities[1]
local coal = GameInfoTypes.RESOURCE_COAL
france.resources[coal], dutch.resources[coal], italy.resources[coal] = 3, 1, 1
local ecsc, eec, eu = FN.OrgByType.ORG_ECSC, FN.OrgByType.ORG_EEC, FN.OrgByType.ORG_EU
RunTurns(1)
Check(FN.OrgActive(ecsc) and FN.IsMember(ecsc, 7) and FN.IsMember(ecsc, 8) and FN.IsMember(ecsc, 9), "the Coal and Steel Community is founded by the coal-owning Six (here three)")
Check(not FN.IsMember(ecsc, 4), "Britain, without coal, stays out")
france.era, dutch.era, italy.era = 6, 6, 6
RunTurns(1)
Check(FN.OrgActive(eec) and not FN.OrgActive(ecsc), "the Economic Community absorbs it")
Check(FN.IsMember(eec, 8) and Teams[7].openBorders[8] == true, "its members keep open borders")
france.era, dutch.era, italy.era = 7, 7, 7
germany.ideology = 1
RunTurns(1)
Check(FN.OrgActive(eu) and not FN.OrgActive(eec), "the European Union replaces the Economic Community")
Check(FN.IsMember(eu, 5) and FN.IsMember(eu, 8), "Germany joins for a shared ideology; EEC members come along")
Check(france:HasPolicy(GameInfoTypes.POLICY_FN_ORG_EU), "members hold the Union's policy")
local function CanWar(a, b) for _, fn in ipairs(GameEvents.PlayerCanDeclareWar) do if fn(a, b) == false then return false end end return true end
Check(not CanWar(7, 8) and CanWar(7, 1), "members cannot declare war on each other, only on others")
dutch.ideology, dutch.unhappy, dutch.denouncing = 2, true, { [9] = true }
local tExit
for i = 1, 50 do RunTurns(1); if not FN.IsMember(eu, 8) then tExit = i break end end
Check(tExit ~= nil, "a disaffected member votes to leave after a referendum (turn " .. tostring(tExit) .. ")")
Check(FN.OrgActive(eu) and not FN.IsMember(eu, 8), "the Union goes on without the leaver")

print("Scenario 13: alliances - collective defence, calls to arms, no separate peace, a player-drafted pact")
local nato = FN.OrgByType.ORG_NATO
Check(FN.OrgActive(nato) and FN.IsMember(nato, 7) and FN.IsMember(nato, 9), "NATO is founded by AI members sharing an ideology")
local turkey = NewPlayer(10, { civ = CIV("OTTOMAN"), name = "Suleiman", era = 7, ideology = 3, might = 50 })
turkey.cities[1] = NewCity(10, 318, 34, "Istanbul"); turkey.origCap = turkey.cities[1]
local far = NewPlayer(11, { civ = CIV("AZTEC"), name = "Montezuma", era = 7, ideology = 3 })
far.cities[1] = NewCity(11, 500, 200, "Tenochtitlan"); far.origCap = far.cities[1]
Teams[11]:DeclareWar(9, false, 11)
RunTurns(1)
Check(not Teams[7].war[11], "an attack from outside the treaty area does not trigger it (regional scope)")
Teams[10]:DeclareWar(9, false, 10)
RunTurns(1)
Check(Teams[7].war[10] and Teams[5].war[10], "an attack on Rome is an attack on all: France and Germany join")
Check(FN.Credibility(nato, 7) > 0, "answering the call raises credibility")
Check(not Teams[7]:CanDeclareWar(9), "members still cannot declare war on each other")

britain.human, britain.cities[1].religion, dutch.cities[1].religion = true, 1, 1
local pactOk = FN.FoundPact(britain, { Name = "Pact of London", Obligation = "DEFENCE", Scope = "GLOBAL", NoSeparatePeace = true,
	Burden = "NONE", Hegemonic = false, OpenBorders = true })
local pact = FN.OrgByType.ORG_PACT_1
Check(pactOk and FN.OrgActive(pact) and FN.IsMember(pact, 8) and pact.Title == "Pact of London", "a player drafts and founds a pact; a co-religionist joins")
Teams[10]:DeclareWar(8, false, 10)
RunTurns(1)
local iEnemy = FN.PendingCall(pact, 4)
Check(iEnemy == 10, "the human member receives a call to arms")
Check(FN.AnswerCall(pact, britain, true) and Teams[4].war[10], "honouring it declares war")
Check(not CanMakePeace(4, 10), "no separate peace while the Netherlands still fights")
Teams[8].war[10], Teams[10].war[8] = false, false
RunTurns(1)
Check(CanMakePeace(4, 10), "once the attacked member has made peace, the others may too")
local tSave = SAVE["FN_PN_ORG_PACT_1"]
Check(tSave == "Pact of London" and SAVE["FN_PT_ORG_PACT_1_NoSeparatePeace"] == "1", "the pact's name and terms are saved")
Check(not FN.CanLeaveOrg(FN.OrgByType.ORG_WARSAW_PACT, britain) and FN.CanLeaveOrg(pact, britain), "only a leading-power pact forbids leaving")
local ok, err = pcall(FN.OpenCharterForTest, { Obligation = "FULL" })
Check(ok, "the charter window opens" .. (ok and "" or (": " .. tostring(err))))
britain.human = false

print("Scenario 14: panel renders every tab without errors")
for _, sTab in ipairs({ "NATIONS", "UNIONS", "ORGS", "PROVINCES", "WORLD" }) do
	local ok, err = pcall(FN.ShowPanelTab, sTab)
	Check(ok, "tab " .. sTab .. (ok and "" or (": " .. tostring(err))))
end

print(FAILS == 0 and "ALL PASSED" or (FAILS .. " FAILED"))
os.exit(FAILS == 0 and 0 or 1)
