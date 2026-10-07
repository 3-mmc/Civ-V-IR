-- Formable Nations: historical City-States at game start (design: "Historical City-States").
-- City-States are drawn at random from ~120, so a formation's partners are often missing (Vilnius in about one game in
-- seven). Once every City-State has founded its city, this swaps in the City-States that the formations of the civs in
-- this game need, replacing the City-State nearest to the civ that will claim it (preferring one of the same trait).
-- The number of City-States stays the same. It uses the engine's own path for replacing a City-State at game start:
-- Game.DoSpawnFreeCity on a City-State's city gives it to a fresh slot "as if founded there" and retires the old one.
-- Runs once per game (save key SETUP_DONE); never later than the first few turns, before most first contacts.
local L = FN.L
local S = FN.S

local function Origin(pMajor)
	local pCapital = pMajor:GetCapitalCity()
	if pCapital then return pCapital:GetX(), pCapital:GetY() end
	local pPlot = pMajor:GetStartingPlot()
	if pPlot then return pPlot:GetX(), pPlot:GetY() end
end

local function Trait(iType)
	local row = GameInfo.MinorCivilizations[iType]
	return row and row.MinorCivTrait
end

-- Returns the list of { Type, For } still missing for the formations of civs in this game, and the set of City-State
-- types those formations refer to (never used as donors).
function FN.HistoricalNeeds()
	local tCivs, tClaimed, tQueued, tNeeds = {}, {}, {}, {}
	for i = 0, FN.MAX_MAJOR - 1 do
		local p = Players[i]
		if p and p:IsEverAlive() then tCivs[p:GetCivilizationType()] = p end
	end
	for _, s in ipairs(FN.Stages) do
		local pMajor = tCivs[s.CivID]
		if pMajor then
			for _, g in ipairs(s.Groups) do
				local iPresent = 0
				for _, claim in ipairs(g.Claims) do
					if claim.MinorID then tClaimed[claim.MinorID] = true end
					if FN.FindClaimPlayer(claim) or (claim.MinorID and tQueued[claim.MinorID]) then iPresent = iPresent + 1 end
				end
				for _, claim in ipairs(g.Claims) do
					if iPresent >= g.Need then break end
					local iType = claim.MinorID
					if iType and not tQueued[iType] and not FN.FindClaimPlayer(claim) and FN.MinorTypeFree(iType) then
						tQueued[iType] = true
						table.insert(tNeeds, { Type = iType, For = pMajor })
						iPresent = iPresent + 1
					end
				end
			end
		end
	end
	-- Priority under the cap: human players' formations first, then one need per civ per round, so no AI civ
	-- takes several swaps before every other civ has had its first.
	local tByCiv, tOrder = {}, {}
	for _, need in ipairs(tNeeds) do
		local iP = need.For:GetID()
		if not tByCiv[iP] then
			tByCiv[iP] = {}
			table.insert(tOrder, need.For)
		end
		table.insert(tByCiv[iP], need)
	end
	local tSorted = {}
	for _, pMajor in ipairs(tOrder) do
		if pMajor:IsHuman() then for _, need in ipairs(tByCiv[pMajor:GetID()]) do table.insert(tSorted, need) end end
	end
	local bMore, iRound = true, 1
	while bMore do
		bMore = false
		for _, pMajor in ipairs(tOrder) do
			local need = not pMajor:IsHuman() and tByCiv[pMajor:GetID()][iRound]
			if need then table.insert(tSorted, need); bMore = true end
		end
		iRound = iRound + 1
	end
	return tSorted, tClaimed
end

local function Swap(pDonor, iType)
	local pCity = pDonor:GetCapitalCity()
	local pPlot = pCity:Plot()
	local sOld = FN.PlayerName(pDonor)
	local iSlot = FN.NextFreeMinorSlot()
	if not iSlot or not FN.PrepareMinorSlot(iSlot, iType) then
		FN.Log("historical City-States: no slot for type %d", iType)
		return false
	end
	local tUnits = {}
	for pUnit in pDonor:Units() do
		if pUnit:IsCombatUnit() then table.insert(tUnits, { Type = pUnit:GetUnitType(), X = pUnit:GetX(), Y = pUnit:GetY() }) end
	end

	Game.DoSpawnFreeCity(pCity) -- not "major founding": the replace-a-City-State path, which retires the donor

	local pNew = Players[iSlot]
	local pNewCity = pPlot:GetPlotCity()
	if not pNewCity or pNewCity:GetOwner() ~= iSlot then
		FN.Log("historical City-States: replacing %s failed", sOld)
		return false
	end
	pNewCity:SetName(L(GameInfo.MinorCivilizations[iType].Description))
	-- That path gives the new City-State the starting Settler; it already has its city. Its garrison takes the
	-- place of the donor's, which died with it.
	local tSettlers = {}
	for pUnit in pNew:Units() do if pUnit:IsFound() then table.insert(tSettlers, pUnit) end end
	for _, pUnit in ipairs(tSettlers) do pUnit:Kill(false, -1) end
	for _, u in ipairs(tUnits) do pNew:InitUnit(u.Type, u.X, u.Y) end
	FN.Log("historical City-States: %s replaced by %s", sOld, FN.PlayerName(pNew))
	return true
end

function FN.SetupHistoricalCityStates()
	if FN.GetN("SETUP_DONE") > 0 then return end
	-- Only at the start of a game: a save from before this feature, or a game already under way, is left alone.
	if S.HISTORICAL_CITY_STATES ~= 1 or Game.GetElapsedGameTurns() > S.HISTORICAL_WAIT_TURNS then FN.Set("SETUP_DONE", 1); return end

	local tDonors, iCityStates, bAllFounded = {}, 0, true
	for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and p:IsAlive() and p:IsMinorCiv() then
			iCityStates = iCityStates + 1
			if p:GetCapitalCity() then table.insert(tDonors, p) else bAllFounded = false end
		end
	end
	-- Wait for the City-States to found their cities, but no longer than a few turns.
	if not bAllFounded and Game.GetElapsedGameTurns() < S.HISTORICAL_WAIT_TURNS then return end
	FN.Set("SETUP_DONE", Game.GetGameTurn() + 1)

	local tNeeds, tClaimed = FN.HistoricalNeeds()
	local iMax = math.floor(iCityStates * S.HISTORICAL_MAX_PERCENT / 100)
	local iDone = 0
	for _, need in ipairs(tNeeds) do
		if iDone >= iMax then break end
		local iX, iY = Origin(need.For)
		local pBest, iBest = nil, nil
		for _, pDonor in ipairs(tDonors) do
			if pDonor:IsAlive() and not tClaimed[pDonor:GetMinorCivType()] then
				local pCity = pDonor:GetCapitalCity()
				local iScore = iX and Map.PlotDistance(iX, iY, pCity:GetX(), pCity:GetY()) or 0
				if Trait(pDonor:GetMinorCivType()) == Trait(need.Type) then iScore = iScore - S.HISTORICAL_TRAIT_PREFERENCE end
				if not iBest or iScore < iBest then pBest, iBest = pDonor, iScore end
			end
		end
		if not pBest then break end
		tClaimed[pBest:GetMinorCivType()] = true -- one swap per donor
		if Swap(pBest, need.Type) then iDone = iDone + 1 end
	end
	FN.Log("historical City-States: %d of %d needed swapped in (cap %d)", iDone, #tNeeds, iMax)
	if iDone > 0 and FN.DrawOverlay then FN.DrawOverlay() end
end
