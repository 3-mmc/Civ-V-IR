-- Formable Nations: cohesion of union bonds (design: "Cohesion and secession").
-- A bond links a union leader to one partner (a City-State, or a vassal major). Absorbed partners have no bond.
-- Save keys per bond, suffix _<leader>_<partner>:
--   B   active (1/0)          BC  cohesion in tenths      BS  turn bonded
--   BI  turn it last reached "integrated" (0 = below)    BR  resting-point change we applied
--   BCR crisis start turn     BCD crisis cooldown until  BSC secession turn (0 = none)
--   BX_CONCEDE / BX_PRIVILEGE / BX_ASSERT: response active until turn
local L = FN.L
local S = FN.S

local function K(sPrefix, iLeader, iPartner) return sPrefix .. "_" .. iLeader .. "_" .. iPartner end

function FN.IsBound(iLeader, iPartner) return FN.GetN(K("B", iLeader, iPartner)) == 1 end
function FN.GetCohesion(iLeader, iPartner) return FN.GetN(K("BC", iLeader, iPartner)) / 10 end

local DRIFT_TENTHS = math.max(1, math.floor(S.COHESION_DRIFT * 10 * 100 / FN.SPEED_PERCENT + 0.5))

------------------------------------------------------------------------------
-- Bond lifecycle
------------------------------------------------------------------------------
local function CreateBond(pLeader, pPartner)
	local iL, iP = pLeader:GetID(), pPartner:GetID()
	if FN.IsBound(iL, iP) then return end
	FN.Set(K("B", iL, iP), 1)
	FN.Set(K("BC", iL, iP), S.COHESION_START * 10)
	FN.Set(K("BS", iL, iP), Game.GetGameTurn())
	for _, sKey in ipairs({ "BI", "BCR", "BCD", "BSC", "BX_CONCEDE", "BX_PRIVILEGE", "BX_ASSERT" }) do FN.Set(K(sKey, iL, iP), 0) end
	FN.Set(K("BR", iL, iP), 0)
	if pPartner:IsMinorCiv() then
		-- Influence settles at the alliance threshold plus a margin instead of decaying away.
		local iWanted = FN.ALLY_THRESHOLD + S.RESTING_ABOVE_ALLY - pPartner:GetMinorCivFriendshipAnchorWithMajor(iL)
		if iWanted > 0 then
			pPartner:ChangeRestingPointChange(iL, iWanted)
			FN.Set(K("BR", iL, iP), iWanted)
		end
	end
	FN.Log("bond %d -> %d created", iL, iP)
end

local function EndBond(iL, iP, sReason)
	if not FN.IsBound(iL, iP) then return end
	local pPartner = Players[iP]
	local iRest = FN.GetN(K("BR", iL, iP))
	if iRest ~= 0 and pPartner and pPartner:IsAlive() and pPartner:IsMinorCiv() then
		pPartner:ChangeRestingPointChange(iL, -iRest)
	end
	FN.Set(K("BR", iL, iP), 0)
	FN.Set(K("B", iL, iP), 0)
	FN.Set(K("BSC", iL, iP), 0)
	FN.Set(K("BCR", iL, iP), 0)
	FN.Log("bond %d -> %d ended (%s)", iL, iP, sReason)
end

-- Partners currently eligible to be bound into union s: UNION claims met by alliance, marriage or vassalage.
local function EligiblePartners(pLeader, s)
	local t = {}
	for _, g in ipairs(s.Groups) do
		for _, claim in ipairs(g.Claims) do
			if claim.Mode == "UNION" then
				local bMet, sState, _, pTarget = FN.EvaluateClaim(pLeader, claim)
				if bMet and pTarget and sState ~= "OWNED" then table.insert(t, pTarget) end
			end
		end
	end
	return t
end

function FN.OnUnionFormed(pLeader, s)
	for _, pPartner in ipairs(EligiblePartners(pLeader, s)) do CreateBond(pLeader, pPartner) end
end

function FN.OnUnionEnded(pLeader, s)
	local iL = pLeader:GetID()
	for _, g in ipairs(s.Groups) do
		for _, claim in ipairs(g.Claims) do
			local pTarget = FN.FindClaimPlayer(claim)
			if pTarget then EndBond(iL, pTarget:GetID(), "union ended") end
		end
	end
end

-- Bonded partners of union s, as { Claim, Partner } pairs.
function FN.BondsOf(pLeader, s)
	local t, iL = {}, pLeader:GetID()
	for _, g in ipairs(s.Groups) do
		for _, claim in ipairs(g.Claims) do
			if claim.Mode == "UNION" then
				local pTarget = FN.FindClaimPlayer(claim)
				if pTarget and FN.IsBound(iL, pTarget:GetID()) then table.insert(t, { Claim = claim, Partner = pTarget, Group = g }) end
			end
		end
	end
	return t
end

-- A bond survives while the partner exists, keeps its capital, and is not at war with (or freed from) the leader.
local function BondValid(pLeader, pPartner)
	if not pPartner:IsAlive() then return false, "partner gone" end
	local pCity = FN.FindClaimCity(pPartner)
	if not pCity or (pCity:GetOwner() ~= pPartner:GetID() and pCity:GetOwner() ~= pLeader:GetID()) then return false, "capital lost" end
	if Teams[pLeader:GetTeam()]:IsAtWar(pPartner:GetTeam()) then return false, "war" end
	if not pPartner:IsMinorCiv() and not Teams[pPartner:GetTeam()]:IsVassal(pLeader:GetTeam()) then return false, "vassalage ended" end
	return true
end

function FN.UnionStillHolds(pLeader, s)
	for _, g in ipairs(s.Groups) do
		local iUnionClaims, iBound = 0, 0
		for _, claim in ipairs(g.Claims) do
			if claim.Mode == "UNION" then
				iUnionClaims = iUnionClaims + 1
				local pTarget = FN.FindClaimPlayer(claim)
				if pTarget then
					local pCity = FN.FindClaimCity(pTarget)
					if (pCity and pCity:GetOwner() == pLeader:GetID()) or FN.IsBound(pLeader:GetID(), pTarget:GetID()) then
						iBound = iBound + 1
					end
				end
			end
		end
		if iUnionClaims > 0 and iBound < g.Need then return false end
	end
	return true
end

------------------------------------------------------------------------------
-- Equilibrium
------------------------------------------------------------------------------
local function MajorityReligion(pPlayer)
	local iState = pPlayer.GetStateReligion and pPlayer:GetStateReligion() or -1
	if iState and iState >= 0 then return iState end
	local pCapital = pPlayer:GetCapitalCity()
	return pCapital and pCapital:GetReligiousMajority() or -1
end

local function HasTradeRoute(pFrom, iTo)
	for _, route in ipairs(pFrom:GetTradeRoutes()) do
		if route.ToID == iTo then return true end
	end
	return false
end

local function AreNeighbours(pLeader, pPartner)
	local pCap = pPartner:GetCapitalCity()
	if not pCap then return false end
	for pCity in pLeader:Cities() do
		if Map.PlotDistance(pCity:GetX(), pCity:GetY(), pCap:GetX(), pCap:GetY()) <= S.NEIGHBOUR_DISTANCE then return true end
	end
	return false
end

local TREATMENT_TERMS = { [0] = 10, [1] = 0, [2] = -10, [3] = -15, [4] = -25 }

-- Returns equilibrium (0-100), list of { Key, Value } terms, and whether any negative cause is active.
function FN.Equilibrium(pLeader, pPartner)
	local iL, iP = pLeader:GetID(), pPartner:GetID()
	local tTerms = {}
	local function Add(sKey, iValue) if iValue ~= 0 then table.insert(tTerms, { Key = sKey, Value = iValue }) end end

	if pPartner:IsMinorCiv() then
		if pPartner:IsAllies(iL) then
			local iMine = pPartner:GetMinorCivFriendshipWithMajor(iL)
			local iRival = 0
			for i = 0, FN.MAX_MAJOR - 1 do
				local p = Players[i]
				if i ~= iL and p and p:IsAlive() then iRival = math.max(iRival, pPartner:GetMinorCivFriendshipWithMajor(i)) end
			end
			Add("LEAD", math.min(S.TERM_LEAD_MAX, math.floor(math.max(0, iMine - iRival) / S.TERM_LEAD_DIVISOR)))
		elseif not pPartner:IsMarried(iL) then
			Add("CONTESTED", S.TERM_CONTESTED)
		end
	else
		Add("TREATMENT", TREATMENT_TERMS[pPartner:GetVassalTreatmentLevel(iL)] or 0)
		if pPartner:GetMilitaryMight() > pLeader:GetMilitaryMight() then Add("STRONGER", S.TERM_STRONGER_VASSAL) end
	end

	local iRelL, iRelP = MajorityReligion(pLeader), MajorityReligion(pPartner)
	if iRelL >= 0 and iRelL == iRelP then Add("RELIGION", S.TERM_RELIGION_SHARED)
	elseif iRelL >= 0 and iRelP >= 0 then Add("RELIGION", S.TERM_RELIGION_DIFFERENT) end

	if HasTradeRoute(pLeader, iP) or (not pPartner:IsMinorCiv() and HasTradeRoute(pPartner, iL)) then Add("TRADE", S.TERM_TRADE) end
	if AreNeighbours(pLeader, pPartner) then Add("NEIGHBOURS", S.TERM_NEIGHBOURS) end

	local iTenure = Game.GetGameTurn() - FN.GetN(K("BS", iL, iP))
	Add("TENURE", math.min(S.TERM_TENURE_MAX, math.floor(iTenure / FN.Turns(10)) * S.TERM_TENURE_PER_10))

	local iWars = Teams[pLeader:GetTeam()]:GetAtWarCount(true)
	Add("WAR", math.max(S.TERM_WAR_MAX, iWars * S.TERM_WAR_EACH))
	if pLeader:IsEmpireUnhappy() then Add("UNHAPPY", S.TERM_UNHAPPY) end

	local iTurn = Game.GetGameTurn()
	if FN.GetN(K("BX_CONCEDE", iL, iP)) > iTurn then Add("CONCEDE", S.CONCEDE_BONUS) end
	if FN.GetN(K("BX_PRIVILEGE", iL, iP)) > iTurn then Add("PRIVILEGE", S.PRIVILEGE_BONUS) end
	if FN.GetN(K("BX_ASSERT", iL, iP)) > iTurn then Add("ASSERT", S.ASSERT_BONUS) end

	local iE, bCause = S.COHESION_BASE, false
	for _, t in ipairs(tTerms) do
		iE = iE + t.Value
		if t.Value < 0 then bCause = true end
	end
	-- Time alone never breaks a union: without an active cause, equilibrium stays at the floor or above.
	if not bCause then iE = math.max(iE, S.COHESION_FLOOR_NO_CAUSE) end
	return math.max(0, math.min(100, iE)), tTerms, bCause
end

------------------------------------------------------------------------------
-- Crises
------------------------------------------------------------------------------
function FN.ConcedeCost(pLeader)
	return math.floor(S.CONCEDE_GOLD_PER_ERA * (pLeader:GetCurrentEra() + 1) * FN.GOLD_PERCENT / 100)
end
function FN.PrivilegeTribute(pLeader)
	return math.max(1, math.floor(S.PRIVILEGE_GOLD_PER_ERA * (pLeader:GetCurrentEra() + 1) * FN.GOLD_PERCENT / 100))
end
function FN.InCrisis(iL, iP) return FN.GetN(K("BCR", iL, iP)) > 0 end

function FN.RespondCrisis(pLeader, pPartner, sChoice)
	local iL, iP = pLeader:GetID(), pPartner:GetID()
	if not FN.InCrisis(iL, iP) then return false end
	local iTurn = Game.GetGameTurn()
	if sChoice == "CONCEDE" then
		local iCost = FN.ConcedeCost(pLeader)
		if pLeader:GetGold() < iCost then return false end
		pLeader:ChangeGold(-iCost)
		FN.Set(K("BX_CONCEDE", iL, iP), iTurn + FN.Turns(S.CONCEDE_TURNS))
	elseif sChoice == "PRIVILEGE" then
		FN.Set(K("BX_PRIVILEGE", iL, iP), iTurn + FN.Turns(S.PRIVILEGE_TURNS))
	elseif sChoice == "ASSERT" then
		for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
			local pMinor = Players[i]
			if i ~= iP and pMinor and pMinor:IsAlive() and pMinor:IsMinorCiv() and pMinor:GetMinorCivFriendshipWithMajor(iL) > 0 then
				pMinor:ChangeMinorCivFriendshipWithMajor(iL, -S.ASSERT_INFLUENCE_COST)
			end
		end
		FN.Set(K("BX_ASSERT", iL, iP), iTurn + FN.Turns(S.ASSERT_TURNS))
	else
		return false
	end
	FN.Set(K("BCR", iL, iP), 0)
	FN.Set(K("BCD", iL, iP), iTurn + FN.Turns(S.CRISIS_COOLDOWN))
	FN.Set("BUCD_" .. iL, iTurn + FN.Turns(S.CRISIS_COOLDOWN))
	FN.Log("crisis %d -> %d answered: %s", iL, iP, sChoice)
	return true
end

local function AIRespond(pLeader, pPartner)
	if pLeader:GetGold() >= 2 * FN.ConcedeCost(pLeader) then
		FN.RespondCrisis(pLeader, pPartner, "CONCEDE")
	else
		FN.RespondCrisis(pLeader, pPartner, "PRIVILEGE")
	end
end

local function Secede(pLeader, pPartner)
	local iL, iP = pLeader:GetID(), pPartner:GetID()
	EndBond(iL, iP, "secession")
	if pPartner:IsMinorCiv() then
		local iInfluence = pPartner:GetMinorCivFriendshipWithMajor(iL)
		if iInfluence > 0 then pPartner:ChangeMinorCivFriendshipWithMajor(iL, -iInfluence) end
	else
		Teams[pLeader:GetTeam()]:DoEndVassal(pPartner:GetTeam(), true, false)
	end
	FN.NotifyKnown(pLeader, L("TXT_KEY_FN_NOTIFY_SECEDED", FN.PlayerName(pPartner), FN.PlayerName(pLeader)),
		L("TXT_KEY_FN_NOTIFY_SECEDED_S", FN.PlayerName(pPartner)))
end

------------------------------------------------------------------------------
-- Integration report for deepening (used by FN.EvaluateStage)
------------------------------------------------------------------------------
function FN.IntegrationReport(pLeader, sUnion, iTurnsNeeded)
	local iL, iTurn, bAll, tLines = pLeader:GetID(), Game.GetGameTurn(), true, {}
	local tBonds = FN.BondsOf(pLeader, sUnion)
	if #tBonds == 0 then
		-- Claims already owned need no partner integration, but still require time under the union.
		local iHeld = FN.TurnsHeld(pLeader, sUnion)
		bAll = FN.UnionStillHolds(pLeader, sUnion) and iHeld >= iTurnsNeeded
		table.insert(tLines, { Ok = bAll, Text = L("TXT_KEY_FN_REQ_PREREQ", sUnion.Title, iTurnsNeeded, iHeld) })
	end
	for _, b in ipairs(tBonds) do
		local iP = b.Partner:GetID()
		local iSince = FN.GetN(K("BI", iL, iP))
		local iHeld = (iSince > 0) and (iTurn - iSince) or 0
		local bOk = iSince > 0 and iHeld >= iTurnsNeeded
		if not bOk then bAll = false end
		table.insert(tLines, { Ok = bOk, Text = L("TXT_KEY_FN_REQ_INTEGRATED", FN.PlayerName(b.Partner),
			math.floor(FN.GetCohesion(iL, iP)), S.COHESION_INTEGRATED, iTurnsNeeded, iHeld) })
	end
	return bAll, tLines
end

------------------------------------------------------------------------------
-- Turn processing for one union leader
------------------------------------------------------------------------------
function FN.ProcessCohesion(pLeader)
	local iL, iTurn = pLeader:GetID(), Game.GetGameTurn()
	for _, s in ipairs(FN.Stages) do
		if s.IsUnion and FN.HasStage(pLeader, s) then
			local bCrisisActive = false
			for _, b in ipairs(FN.BondsOf(pLeader, s)) do
				if FN.InCrisis(iL, b.Partner:GetID()) then bCrisisActive = true end
			end
			-- New partners who qualify join automatically (e.g. a third imperial estate).
			for _, pPartner in ipairs(EligiblePartners(pLeader, s)) do
				if not FN.IsBound(iL, pPartner:GetID()) then
					CreateBond(pLeader, pPartner)
					FN.Notify(pLeader, L("TXT_KEY_FN_NOTIFY_JOINED_UNION", FN.PlayerName(pPartner), s.Title), L("TXT_KEY_FN_NOTIFY_JOINED_UNION_S", FN.PlayerName(pPartner)))
				end
			end

			for _, b in ipairs(FN.BondsOf(pLeader, s)) do
				local pPartner = b.Partner
				local iP = pPartner:GetID()
				local bValid, sWhy = BondValid(pLeader, pPartner)
				if not bValid then
					EndBond(iL, iP, sWhy)
				else
					local iE, tTerms = FN.Equilibrium(pLeader, pPartner)
					local iC = FN.GetN(K("BC", iL, iP))
					local iTarget = iE * 10
					if iC < iTarget then iC = math.min(iTarget, iC + DRIFT_TENTHS)
					elseif iC > iTarget then iC = math.max(iTarget, iC - DRIFT_TENTHS) end
					FN.Set(K("BC", iL, iP), iC)
					local fC = iC / 10

					-- Integration clock for deepening.
					if fC >= S.COHESION_INTEGRATED then
						if FN.GetN(K("BI", iL, iP)) == 0 then FN.Set(K("BI", iL, iP), iTurn) end
					else
						FN.Set(K("BI", iL, iP), 0)
					end

					-- Privileges cost tribute every turn they are in force.
					if FN.GetN(K("BX_PRIVILEGE", iL, iP)) > iTurn then
						pLeader:ChangeGold(-math.min(pLeader:GetGold(), FN.PrivilegeTribute(pLeader)))
					end

					-- Crisis: open, lapse.
					local iCrisis = FN.GetN(K("BCR", iL, iP))
					if iCrisis > 0 and iTurn - iCrisis >= FN.Turns(S.CRISIS_EXPIRES) then
						FN.Set(K("BCR", iL, iP), 0)
						FN.Set(K("BCD", iL, iP), iTurn + FN.Turns(S.CRISIS_COOLDOWN))
						FN.Set("BUCD_" .. iL, iTurn + FN.Turns(S.CRISIS_COOLDOWN))
						iCrisis = 0
					end
					if not bCrisisActive and FN.GetN("BUCD_" .. iL) <= iTurn and iCrisis == 0 and fC < S.COHESION_CRISIS and fC >= S.COHESION_SECESSION and FN.GetN(K("BCD", iL, iP)) <= iTurn then
						FN.Set(K("BCR", iL, iP), iTurn)
						bCrisisActive = true
						FN.Log("crisis %d -> %d at cohesion %.1f", iL, iP, fC)
						if pLeader:IsHuman() then
							FN.Notify(pLeader, L("TXT_KEY_FN_NOTIFY_CRISIS", FN.PlayerName(pPartner), s.Title), L("TXT_KEY_FN_NOTIFY_CRISIS_S", FN.PlayerName(pPartner)))
						else
							AIRespond(pLeader, pPartner)
						end
					end

					-- Secession: countdown below the threshold, cancelled if cohesion recovers.
					local iSecede = FN.GetN(K("BSC", iL, iP))
					if fC < S.COHESION_SECESSION then
						if iSecede == 0 then
							FN.Set(K("BSC", iL, iP), iTurn + FN.Turns(S.SECESSION_COUNTDOWN))
							FN.NotifyKnown(pLeader, L("TXT_KEY_FN_NOTIFY_SECESSION_WARNING", FN.PlayerName(pPartner), FN.PlayerName(pLeader), FN.Turns(S.SECESSION_COUNTDOWN)),
								L("TXT_KEY_FN_NOTIFY_SECESSION_WARNING_S", FN.PlayerName(pPartner)))
						elseif iTurn >= iSecede then
							Secede(pLeader, pPartner)
						end
					elseif iSecede > 0 then
						FN.Set(K("BSC", iL, iP), 0)
						FN.Notify(pLeader, L("TXT_KEY_FN_NOTIFY_SECESSION_AVERTED", FN.PlayerName(pPartner)), L("TXT_KEY_FN_NOTIFY_SECESSION_AVERTED_S", FN.PlayerName(pPartner)))
					end

					local tParts = {}
					for _, t in ipairs(tTerms) do table.insert(tParts, t.Key .. "=" .. t.Value) end
					FN.Log("cohesion %d -> %d: %.1f toward %d [%s]", iL, iP, iC / 10, iE, table.concat(tParts, " "))
				end
			end

			if not FN.UnionStillHolds(pLeader, s) then FN.DissolveStage(pLeader, s) end
		end
	end
end

-- Forecast for the panel: turns until cohesion crosses the secession threshold at the current drift, or nil.
function FN.SecessionForecast(iL, iP, iEquilibrium)
	local fC = FN.GetCohesion(iL, iP)
	if iEquilibrium >= S.COHESION_SECESSION or fC < S.COHESION_SECESSION then return nil end
	return math.ceil((fC - S.COHESION_SECESSION) * 10 / DRIFT_TENTHS)
end
