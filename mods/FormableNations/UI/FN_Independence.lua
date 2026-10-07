-- Formable Nations: independence and fragmentation (design: "Independence and fragmentation").
-- Cities that are not integrated (colonies on another landmass, cities of another people) carry a local cohesion
-- score that drifts toward an equilibrium, like union bonds. Low cohesion opens an independence movement; very low
-- cohesion starts a countdown, after which the city breaks away: back to a dead civilization (national revival),
-- back to its living original owner, or as a free City-State. Restless cities nearby go with it (fragmentation).
-- Capitals, cities on the home landmass and partners absorbed by a formation are integrated and never break away.
-- Save keys per city, by plot index p:
--   CW_p owner+1 the record belongs to (a new owner starts afresh)   CC_p cohesion in tenths
--   CI_p turn it last reached "integrated" (0 = below)                CG_p owner+1 once integrated for good
--   CQ_p owner+1 that took it by conquest                             CM_p movement start turn (0 = none)
--   CMD_p no new movement before this turn                            CS_p breakaway turn (0 = no countdown)
--   CX_AUTONOMY_p / CX_SUPPRESS_p response active until turn
-- Per player: BRK_<player> turn of the last breakaway.
local L = FN.L
local S = FN.S

local ERA = {}
for row in GameInfo.FormableNation_EraSettings() do ERA[row.Name] = GameInfo.Eras[row.EraType].ID end

local OPINION_CIVIL_RESISTANCE = 2   -- PublicOpinionTypes in CvCultureClasses.h
local OPINION_REVOLUTIONARY_WAVE = 3
local CITY_DRIFT_TENTHS = math.max(1, math.floor(S.CITY_DRIFT * 10 * 100 / FN.SPEED_PERCENT + 0.5))

local function PI(pCity) return pCity:Plot():GetPlotIndex() end
local function CK(sPrefix, iPlot) return sPrefix .. "_" .. iPlot end

function FN.CityCohesion(pCity) return FN.GetN(CK("CC", PI(pCity))) / 10 end
function FN.InMovement(pCity) return FN.GetN(CK("CM", PI(pCity))) > 0 end
function FN.BreakawayTurn(pCity) return FN.GetN(CK("CS", PI(pCity))) end

------------------------------------------------------------------------------
-- Integration status
------------------------------------------------------------------------------
-- "COLONY" or "FOREIGN" can break away; "CORE" and "INTEGRATED" never do; "NONE" for non-major owners.
function FN.CityKind(pCity)
	local iOwner = pCity:GetOwner()
	local pOwner = Players[iOwner]
	if not pOwner or iOwner >= FN.MAX_MAJOR then return "NONE" end
	if pCity:IsCapital() then return "CORE" end
	local iPlot = PI(pCity)
	if FN.GetN(CK("CG", iPlot)) == iOwner + 1 then return "INTEGRATED" end

	local iOrig = pCity:GetOriginalOwner()
	if iOrig ~= iOwner then
		if FN.GetN(CK("CQ", iPlot)) == iOwner + 1 then return "FOREIGN" end
		if iOrig >= 0 and iOrig < FN.MAX_MAJOR then return "FOREIGN" end -- traded or ceded cities of another nation
		return "CORE" -- City-States joined peacefully: buyout, marriage, formation
	end

	local pCapital = pOwner:GetCapitalCity()
	if not pCapital then return "CORE" end
	if pCity:Plot():GetArea() ~= pCapital:Plot():GetArea()
		and Map.PlotDistance(pCity:GetX(), pCity:GetY(), pCapital:GetX(), pCapital:GetY()) >= S.COLONY_MIN_DISTANCE then
		return "COLONY"
	end
	return "CORE"
end

local function MajorityReligion(pPlayer)
	local iState = pPlayer.GetStateReligion and pPlayer:GetStateReligion() or -1
	if iState and iState >= 0 then return iState end
	local pCapital = pPlayer:GetCapitalCity()
	return pCapital and pCapital:GetReligiousMajority() or -1
end

-- Returns equilibrium (0-100) and a list of { Key, Value } terms.
function FN.CityEquilibrium(pCity, sKind)
	local pOwner = Players[pCity:GetOwner()]
	local iPlot, iTurn = PI(pCity), Game.GetGameTurn()
	local tTerms = {}
	local function Add(sKey, iValue) if iValue ~= 0 then table.insert(tTerms, { Key = sKey, Value = iValue }) end end

	if pOwner:IsCapitalConnectedToCity(pCity) then Add("CONNECTED", S.TERM_CONNECTED) else Add("NOT_CONNECTED", S.TERM_NOT_CONNECTED) end

	local iOwnerRel, iCityRel = MajorityReligion(pOwner), pCity:GetReligiousMajority()
	if iOwnerRel >= 0 and iCityRel >= 0 then
		Add("CITY_RELIGION", iOwnerRel == iCityRel and S.TERM_CITY_RELIGION_SHARED or S.TERM_CITY_RELIGION_DIFFERENT)
	end
	if pCity:GetGarrisonedUnit() then Add("GARRISON", S.TERM_GARRISON) end
	if pCity:IsPuppet() then Add("PUPPET", S.TERM_PUPPET) end

	local iSince = (sKind == "COLONY") and pCity:GetGameTurnFounded() or pCity:GetGameTurnAcquired()
	Add("CITY_TENURE", math.min(S.TERM_CITY_TENURE_MAX, math.floor(math.max(0, iTurn - iSince) / FN.Turns(10)) * S.TERM_CITY_TENURE_PER_10))

	local pCapital = pOwner:GetCapitalCity()
	if pCapital then
		local iOver = Map.PlotDistance(pCity:GetX(), pCity:GetY(), pCapital:GetX(), pCapital:GetY()) - S.COLONY_MIN_DISTANCE
		if iOver > 0 then Add("DISTANCE", math.max(S.TERM_DISTANCE_MAX, -math.floor(iOver / S.DISTANCE_STEP))) end
	end

	if sKind == "FOREIGN" then
		local iOrig = pCity:GetOriginalOwner()
		if iOrig >= 0 and iOrig < FN.MAX_MAJOR then
			Add("FOREIGN", Players[iOrig]:IsAlive() and S.TERM_FOREIGN_ALIVE or S.TERM_FOREIGN_DEAD)
		else
			Add("FOREIGN", S.TERM_FOREIGN_MINOR)
		end
	end

	local iEra = pOwner:GetCurrentEra()
	if iEra >= ERA.NATIONALISM then
		Add("NATIONALISM", math.max(S.TERM_NATIONALISM_MAX, (iEra - ERA.NATIONALISM + 1) * S.TERM_NATIONALISM_PER_ERA))
	end

	-- Only the worst level of empire unhappiness counts.
	if pOwner:IsEmpireSuperUnhappy() then Add("UNHAPPY", S.TERM_CITY_SUPER_UNHAPPY)
	elseif pOwner:IsEmpireVeryUnhappy() then Add("UNHAPPY", S.TERM_CITY_VERY_UNHAPPY)
	elseif pOwner:IsEmpireUnhappy() then Add("UNHAPPY", S.TERM_CITY_UNHAPPY) end

	local iOpinion = pOwner:GetPublicOpinionType()
	if iOpinion == OPINION_REVOLUTIONARY_WAVE then Add("OPINION", S.TERM_REVOLUTIONARY_WAVE)
	elseif iOpinion == OPINION_CIVIL_RESISTANCE then Add("OPINION", S.TERM_CIVIL_RESISTANCE) end

	if FN.GetN(CK("CX_AUTONOMY", iPlot)) > iTurn then Add("AUTONOMY", S.AUTONOMY_BONUS) end
	if FN.GetN(CK("CX_SUPPRESS", iPlot)) > iTurn then Add("SUPPRESS", S.SUPPRESS_BONUS) end

	local iE, bCause = S.CITY_BASE, false
	for _, t in ipairs(tTerms) do
		iE = iE + t.Value
		if t.Value < 0 then bCause = true end
	end
	-- As with unions: time alone never sets a city on the road to independence.
	if not bCause then iE = math.max(iE, S.CITY_FLOOR_NO_CAUSE) end
	return math.max(0, math.min(100, iE)), tTerms
end

------------------------------------------------------------------------------
-- Where a breakaway city goes
------------------------------------------------------------------------------
local function TypeTaken(iType)
	for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and p:IsEverAlive() and p:GetMinorCivType() == iType then return true end
	end
	return false
end

local function BlockedTypes()
	local tCivs, tBlocked = {}, {}
	for i = 0, FN.MAX_MAJOR - 1 do
		local p = Players[i]
		if p and p:IsEverAlive() then tCivs[p:GetCivilizationType()] = true end
	end
	for row in GameInfo.MajorBlocksMinor() do
		local iCiv, iMinor = GameInfoTypes[row.MajorCiv], GameInfoTypes[row.MinorCiv]
		if iCiv and iMinor and tCivs[iCiv] then tBlocked[iMinor] = true end
	end
	return tBlocked
end

-- Returns the City-State type for a new free City-State and whether the city should take its name.
-- 1. A City-State named like the city (a seceding "Dublin" becomes Dublin). 2. For colonies, a colonial-era type.
-- 3. Any unused type. Types already in this game, or blocked by a civilization in it, are never chosen.
function FN.MinorTypeFree(iType)
	return iType ~= nil and iType >= 0 and not BlockedTypes()[iType] and not TypeTaken(iType)
end

function FN.PickBreakawayType(pCity, sKind)
	local tBlocked = BlockedTypes()
	local function Free(iType) return iType and not tBlocked[iType] and not TypeTaken(iType) end
	local sName = string.lower(pCity:GetName())
	local tAll = {}
	for row in GameInfo.MinorCivilizations() do
		if Free(row.ID) then
			if string.lower(L(row.Description)) == sName then return row.ID, false end
			-- Formation-only City-States (Playable = 0) are kept for their formations, not handed out at random.
			if row.Playable ~= 0 and row.Playable ~= false then table.insert(tAll, row.ID) end
		end
	end
	local bRename = (S.RENAME_BREAKAWAY == 1)
	if sKind == "COLONY" then
		local tColonial = {}
		for row in GameInfo.FormableNation_ColonialStates() do
			local iType = GameInfoTypes[row.MinorCivType]
			if Free(iType) then table.insert(tColonial, iType) end
		end
		if #tColonial > 0 then return tColonial[Game.Rand(#tColonial, "FN breakaway type") + 1], bRename end
	end
	if #tAll > 0 then return tAll[Game.Rand(#tAll, "FN breakaway type") + 1], bRename end
	return nil
end

-- Returns { Mode = "REVIVE" | "RETURN" | "FREE", Player, Slot, MinorType, NewSlot, Rename } or nil.
-- FREE mirrors CvGame::GetPotentialFreeCityPlayer: a dead City-State that once held the city comes back first,
-- otherwise the first never-used City-State slot opens (and we choose its type).
function FN.BreakawayDestination(pOwner, pCity, sKind)
	local iOrig = pCity:GetOriginalOwner()
	if sKind == "FOREIGN" and iOrig >= 0 and iOrig < FN.MAX_MAJOR and iOrig ~= pOwner:GetID() then
		local pOrig = Players[iOrig]
		if not pOrig:IsAlive() then return { Mode = "REVIVE", Player = iOrig } end
		if not Teams[pOwner:GetTeam()]:IsAtWar(pOrig:GetTeam()) then return { Mode = "RETURN", Player = iOrig } end
	end
	for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and not p:IsAlive() and pCity:GetNumTimesOwned(i) > 0 then
			return { Mode = "FREE", Slot = i, MinorType = p:GetMinorCivType() }
		end
	end
	local iSlot = FN.NextFreeMinorSlot()
	if not iSlot then return nil end
	local iType, bRename = FN.PickBreakawayType(pCity, sKind)
	if not iType then return nil end
	return { Mode = "FREE", Slot = iSlot, MinorType = iType, NewSlot = true, Rename = bRename }
end

-- The slot the engine opens for a new City-State that no dead City-State has a claim on: the first never-used one.
function FN.NextFreeMinorSlot()
	for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and not p:IsEverAlive() and not p:IsObserver() then return i end
	end
end

-- Sets the type of a never-used slot and checks it took; false if the slot kept another type.
function FN.PrepareMinorSlot(iSlot, iType)
	Game.ChangeMinorPlayer(iSlot, iType)
	return Players[iSlot]:GetMinorCivType() == iType
end

function FN.CanBreakAway(pOwner, pCity, sKind)
	if pCity:IsCapital() or (sKind ~= "COLONY" and sKind ~= "FOREIGN") then return false end
	local iEra = pOwner:GetCurrentEra()
	if sKind == "COLONY" and iEra < ERA.COLONY_INDEPENDENCE then return false end
	if sKind == "FOREIGN" and iEra < ERA.FOREIGN_INDEPENDENCE then return false end
	local iLast = FN.GetN("BRK_" .. pOwner:GetID())
	if iLast > 0 and Game.GetGameTurn() - iLast < FN.Turns(S.BREAKAWAY_COOLDOWN) then return false end
	return FN.BreakawayDestination(pOwner, pCity, sKind) ~= nil
end

------------------------------------------------------------------------------
-- Breakaway
------------------------------------------------------------------------------
local function ClearCity(iPlot)
	for _, sKey in ipairs({ "CW", "CC", "CI", "CM", "CMD", "CS", "CX_AUTONOMY", "CX_SUPPRESS" }) do FN.Set(CK(sKey, iPlot), 0) end
end

-- Restless cities that go with the breakaway: same kind, a movement under way, and either near the city
-- (same landmass) or, for a national revival or return, belonging originally to the same nation.
local function Followers(pOwner, pCity, sKind, d)
	local t, iCityPlot = {}, PI(pCity)
	local iOwner = pOwner:GetID()
	for pOther in pOwner:Cities() do
		if #t >= S.FRAGMENT_MAX_EXTRA then break end
		local iPlot = PI(pOther)
		if iPlot ~= iCityPlot and FN.CityKind(pOther) == sKind and FN.GetN(CK("CW", iPlot)) == iOwner + 1
			and FN.GetN(CK("CC", iPlot)) < S.CITY_MOVEMENT * 10 then
			local bJoin
			if d.Mode == "FREE" then
				bJoin = pOther:Plot():GetArea() == pCity:Plot():GetArea()
					and Map.PlotDistance(pOther:GetX(), pOther:GetY(), pCity:GetX(), pCity:GetY()) <= S.FRAGMENT_RADIUS
			else
				bJoin = pOther:GetOriginalOwner() == d.Player
			end
			if bJoin then table.insert(t, pOther) end
		end
	end
	return t
end

local function SpawnDefenders(pPlayer, pCity)
	local iBest, iBestCombat = nil, 0
	for unit in GameInfo.Units() do
		-- CanTrain's flags are read as integers (luaL_optint), not booleans: bContinue, bTestVisible, bIgnoreCost.
		if unit.Domain == "DOMAIN_LAND" and (unit.Combat or 0) > iBestCombat and pCity:CanTrain(unit.ID, 0, 0, 1) then
			iBest, iBestCombat = unit.ID, unit.Combat
		end
	end
	if not iBest then return end
	for _ = 1, S.REVIVAL_UNITS do pPlayer:InitUnit(iBest, pCity:GetX(), pCity:GetY()) end
end

-- bReleased: granted peacefully by the owner instead of a secession.
function FN.BreakAway(pOwner, pCity, sKind, bReleased)
	local d = FN.BreakawayDestination(pOwner, pCity, sKind)
	if not d then return false end
	local iOwner = pOwner:GetID()
	local pPlot = pCity:Plot()
	local iPlot, iX, iY = pPlot:GetPlotIndex(), pCity:GetX(), pCity:GetY()
	local sOldName = pCity:GetName()
	local tFollowers = Followers(pOwner, pCity, sKind, d) -- before anything changes hands

	local iNew
	if d.Mode == "FREE" then
		if d.NewSlot and not FN.PrepareMinorSlot(d.Slot, d.MinorType) then
			-- Never risk a duplicate City-State: if the slot did not take the type, keep its own only if that is unused.
			local iActual = Players[d.Slot]:GetMinorCivType()
			if not FN.MinorTypeFree(iActual) then
				FN.Log("breakaway of %s: slot %d kept type %d, which is in use; skipped", sOldName, d.Slot, iActual)
				return false
			end
			d.MinorType, d.Rename = iActual, (S.RENAME_BREAKAWAY == 1)
		end
		Game.DoSpawnFreeCity(pCity, true) -- "as if founded by the City-State": it becomes its original capital
		iNew = d.Slot
	elseif d.Mode == "REVIVE" then
		Players[d.Player]:AcquireCity(pCity, false, false) -- as VP's liberation; the engine revives the civ
		iNew = d.Player
	else
		Players[d.Player]:AcquireCity(pCity, false, true)
		iNew = d.Player
	end
	pCity = nil -- the old city object is gone

	local pNewCity = pPlot:GetPlotCity()
	if not pNewCity or pNewCity:GetOwner() ~= iNew then
		FN.Log("breakaway of %s (%s) failed", sOldName, d.Mode)
		return false
	end
	local pNew = Players[iNew]
	if d.Mode == "FREE" and d.Rename then pNewCity:SetName(L(GameInfo.MinorCivilizations[d.MinorType].Description)) end
	if d.Mode == "REVIVE" then SpawnDefenders(pNew, pNewCity) end
	for _, pFollower in ipairs(tFollowers) do
		ClearCity(PI(pFollower))
		pNew:AcquireCity(pFollower, false, true)
	end
	if pNew:IsMinorCiv() then
		pNew:ChangeMinorCivFriendshipWithMajor(iOwner, bReleased and S.RELEASE_INFLUENCE or S.BREAKAWAY_INFLUENCE)
	end
	ClearCity(iPlot)
	FN.Set("BRK_" .. iOwner, Game.GetGameTurn())

	local sNew = pNew:IsMinorCiv() and FN.PlayerName(pNew) or L(pNew:GetCivilizationShortDescriptionKey())
	local sKey = (d.Mode == "REVIVE" and "TXT_KEY_FN_NOTIFY_REVIVED") or (d.Mode == "RETURN" and "TXT_KEY_FN_NOTIFY_RETURNED")
		or (bReleased and "TXT_KEY_FN_NOTIFY_RELEASED") or "TXT_KEY_FN_NOTIFY_INDEPENDENCE"
	local sText = L(sKey, sOldName, FN.PlayerName(pOwner), sNew)
	if #tFollowers > 0 then sText = sText .. " " .. L("TXT_KEY_FN_NOTIFY_FOLLOWERS", #tFollowers) end
	FN.NotifyKnown(pOwner, sText, L(sKey .. "_S", sNew), iX, iY)
	FN.Log("%s left player %d (%s, %s) -> player %d %s, with %d more", sOldName, iOwner, sKind, d.Mode, iNew, sNew, #tFollowers)
	if FN.DrawOverlay then FN.DrawOverlay() end
	return true
end

------------------------------------------------------------------------------
-- Responses to a movement
------------------------------------------------------------------------------
function FN.AutonomyCost(pOwner)
	return math.floor(S.AUTONOMY_GOLD_PER_ERA * (pOwner:GetCurrentEra() + 1) * FN.GOLD_PERCENT / 100)
end

-- sChoice: AUTONOMY (gold), SUPPRESS (needs a garrison; the city falls into resistance), RELEASE (let it go in peace).
function FN.RespondMovement(pOwner, pCity, sChoice)
	if pCity:GetOwner() ~= pOwner:GetID() or not FN.InMovement(pCity) then return false end
	local iPlot, iTurn = PI(pCity), Game.GetGameTurn()
	if sChoice == "AUTONOMY" then
		local iCost = FN.AutonomyCost(pOwner)
		if pOwner:GetGold() < iCost then return false end
		pOwner:ChangeGold(-iCost)
		FN.Set(CK("CX_AUTONOMY", iPlot), iTurn + FN.Turns(S.AUTONOMY_TURNS))
	elseif sChoice == "SUPPRESS" then
		if not pCity:GetGarrisonedUnit() then return false end
		FN.Set(CK("CX_SUPPRESS", iPlot), iTurn + FN.Turns(S.SUPPRESS_TURNS))
		pCity:ChangeResistanceTurns(S.SUPPRESS_RESISTANCE)
	elseif sChoice == "RELEASE" then
		FN.Log("player %d releases %s", pOwner:GetID(), pCity:GetName())
		return FN.BreakAway(pOwner, pCity, FN.CityKind(pCity), true)
	else
		return false
	end
	FN.Set(CK("CM", iPlot), 0)
	FN.Set(CK("CMD", iPlot), iTurn + FN.Turns(S.MOVEMENT_COOLDOWN))
	FN.Log("movement in %s answered: %s", pCity:GetName(), sChoice)
	return true
end

local function AIRespond(pOwner, pCity)
	if pOwner:GetGold() >= 2 * FN.AutonomyCost(pOwner) then
		FN.RespondMovement(pOwner, pCity, "AUTONOMY")
	elseif pCity:GetGarrisonedUnit() then
		FN.RespondMovement(pOwner, pCity, "SUPPRESS")
	end
end

------------------------------------------------------------------------------
-- Turn processing
------------------------------------------------------------------------------
local function ProcessCity(pOwner, pCity, sKind)
	local iOwner, iTurn = pOwner:GetID(), Game.GetGameTurn()
	local iPlot = PI(pCity)
	if FN.GetN(CK("CW", iPlot)) ~= iOwner + 1 then
		ClearCity(iPlot)
		FN.Set(CK("CW", iPlot), iOwner + 1)
		FN.Set(CK("CC", iPlot), S.CITY_START * 10)
	end

	local iE, tTerms = FN.CityEquilibrium(pCity, sKind)
	local iC, iTarget = FN.GetN(CK("CC", iPlot)), iE * 10
	if iC < iTarget then iC = math.min(iTarget, iC + CITY_DRIFT_TENTHS)
	elseif iC > iTarget then iC = math.max(iTarget, iC - CITY_DRIFT_TENTHS) end
	FN.Set(CK("CC", iPlot), iC)
	local fC = iC / 10
	local sName = pCity:GetName()

	-- Integration: once held high long enough, the city is part of the nation for good.
	if fC >= S.CITY_INTEGRATED then
		local iSince = FN.GetN(CK("CI", iPlot))
		if iSince == 0 then
			FN.Set(CK("CI", iPlot), iTurn)
		elseif iTurn - iSince >= FN.Turns(S.CITY_INTEGRATION_TURNS) then
			ClearCity(iPlot)
			FN.Set(CK("CG", iPlot), iOwner + 1)
			FN.Notify(pOwner, L("TXT_KEY_FN_NOTIFY_INTEGRATED", sName), L("TXT_KEY_FN_NOTIFY_INTEGRATED_S", sName), pCity:GetX(), pCity:GetY())
			FN.Log("%s integrated into player %d", sName, iOwner)
			return
		end
	else
		FN.Set(CK("CI", iPlot), 0)
	end

	-- Movement: opens below the threshold, subsides when cohesion recovers.
	local iMovement = FN.GetN(CK("CM", iPlot))
	if iMovement == 0 and fC < S.CITY_MOVEMENT and FN.GetN(CK("CMD", iPlot)) <= iTurn then
		FN.Set(CK("CM", iPlot), iTurn)
		FN.Log("independence movement in %s (player %d) at cohesion %.1f", sName, iOwner, fC)
		if pOwner:IsHuman() then
			FN.Notify(pOwner, L("TXT_KEY_FN_NOTIFY_MOVEMENT", sName), L("TXT_KEY_FN_NOTIFY_MOVEMENT_S", sName), pCity:GetX(), pCity:GetY())
		else
			AIRespond(pOwner, pCity)
		end
	elseif iMovement > 0 and fC >= S.CITY_MOVEMENT then
		FN.Set(CK("CM", iPlot), 0)
	end

	-- Breakaway: a visible countdown below the secession threshold; it waits while a breakaway is not yet possible
	-- (era, cooldown) and is cancelled if cohesion recovers.
	local iSecede = FN.GetN(CK("CS", iPlot))
	if fC < S.CITY_SECESSION then
		if iSecede == 0 then
			if FN.CanBreakAway(pOwner, pCity, sKind) then
				FN.Set(CK("CS", iPlot), iTurn + FN.Turns(S.CITY_COUNTDOWN))
				FN.NotifyKnown(pOwner, L("TXT_KEY_FN_NOTIFY_BREAKAWAY_WARNING", sName, FN.PlayerName(pOwner), FN.Turns(S.CITY_COUNTDOWN)),
					L("TXT_KEY_FN_NOTIFY_BREAKAWAY_WARNING_S", sName), pCity:GetX(), pCity:GetY())
			end
		elseif iTurn >= iSecede and FN.CanBreakAway(pOwner, pCity, sKind) then
			FN.BreakAway(pOwner, pCity, sKind, false)
			return
		end
	elseif iSecede > 0 then
		FN.Set(CK("CS", iPlot), 0)
		FN.Notify(pOwner, L("TXT_KEY_FN_NOTIFY_BREAKAWAY_AVERTED", sName), L("TXT_KEY_FN_NOTIFY_BREAKAWAY_AVERTED_S", sName), pCity:GetX(), pCity:GetY())
	end

	local tParts = {}
	for _, t in ipairs(tTerms) do table.insert(tParts, t.Key .. "=" .. t.Value) end
	FN.Log("city %s (player %d, %s): %.1f toward %d [%s]", sName, iOwner, sKind, fC, iE, table.concat(tParts, " "))
end

function FN.ProcessProvinces(pOwner)
	local iOwner = pOwner:GetID()
	local tCities = {}
	for pCity in pOwner:Cities() do table.insert(tCities, pCity) end
	for _, pCity in ipairs(tCities) do
		-- A breakaway earlier in this loop may have taken followers with it.
		if pCity:GetOwner() == iOwner then
			local sKind = FN.CityKind(pCity)
			if sKind == "COLONY" or sKind == "FOREIGN" then ProcessCity(pOwner, pCity, sKind) end
		end
	end
end

-- Not-yet-integrated cities of a player, most restless first, for the panel.
function FN.Provinces(pOwner)
	local t = {}
	for pCity in pOwner:Cities() do
		local sKind = FN.CityKind(pCity)
		if sKind == "COLONY" or sKind == "FOREIGN" then table.insert(t, { City = pCity, Kind = sKind }) end
	end
	table.sort(t, function(a, b) return FN.CityCohesion(a.City) < FN.CityCohesion(b.City) end)
	return t
end

function FN.IntegrationForecast(pCity)
	local iSince = FN.GetN(CK("CI", PI(pCity)))
	if iSince == 0 then return nil end
	return math.max(0, FN.Turns(S.CITY_INTEGRATION_TURNS) - (Game.GetGameTurn() - iSince))
end

-- Conquest marks a city as "of another people" for its new owner; any change of hands starts a fresh record.
function FN.OnCityCaptured(iOldOwner, bCapital, iX, iY, iNewOwner, iPop, bConquest)
	local pPlot = Map.GetPlot(iX, iY)
	if not pPlot then return end
	local iPlot = pPlot:GetPlotIndex()
	FN.Set(CK("CQ", iPlot), (bConquest and iNewOwner >= 0 and iNewOwner < FN.MAX_MAJOR) and (iNewOwner + 1) or 0)
	FN.Set(CK("CW", iPlot), 0)
end
