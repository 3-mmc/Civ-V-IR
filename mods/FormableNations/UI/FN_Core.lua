-- Formable Nations: shared state, claims, identity, formation. Design: CivVNeo/docs/formable-nations-design.md
-- All modules share the global table FN (they are included into one UI context).
FN = FN or {}
local L = Locale.ConvertTextKey
FN.L = L
FN.MAX_MAJOR = GameDefines.MAX_MAJOR_CIVS
FN.MAX_CIV = GameDefines.MAX_CIV_PLAYERS
FN.ALLY_THRESHOLD = GameDefines.FRIENDSHIP_THRESHOLD_ALLIES or 60

------------------------------------------------------------------------------
-- Settings and game speed
------------------------------------------------------------------------------
FN.S = {}
for row in GameInfo.FormableNation_Settings() do FN.S[row.Name] = row.Value end

local gameSpeed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
FN.SPEED_PERCENT = (gameSpeed and gameSpeed.TrainPercent) or 100
FN.GOLD_PERCENT = (gameSpeed and gameSpeed.GoldPercent) or 100
function FN.Turns(iTurns)
	if iTurns <= 0 then return 0 end
	return math.max(1, math.floor(iTurns * FN.SPEED_PERCENT / 100 + 0.5))
end
FN.UNION_TURNS = FN.Turns(FN.S.UNION_ALLIED_TURNS)

------------------------------------------------------------------------------
-- Save data. Values are numbers; 0 means "unset" so nothing ever needs deleting.
------------------------------------------------------------------------------
local g_SaveData = Modding.OpenSaveData()
function FN.Get(sKey) return g_SaveData.GetValue("FN_" .. sKey) end
function FN.GetN(sKey) return tonumber(g_SaveData.GetValue("FN_" .. sKey)) or 0 end
function FN.Set(sKey, value) g_SaveData.SetValue("FN_" .. sKey, value) end

function FN.Log(sFormat, ...)
	print("[FN] T" .. Game.GetGameTurn() .. " " .. string.format(sFormat, ...))
end

------------------------------------------------------------------------------
-- Stage data
------------------------------------------------------------------------------
FN.Stages = {}
FN.StageByType = {}
for row in GameInfo.FormableNations() do
	local s = {
		Type = row.Type, Chain = row.Chain, Stage = row.Stage, Tier = row.Tier,
		IsUnion = (row.IsUnion == true or row.IsUnion == 1),
		CivID = GameInfoTypes[row.CivilizationType],
		Title = row.Title, Desc = row.Description, Short = row.ShortDescription, Adj = row.Adjective,
		Help = row.Help, Quote = row.Quote,
		MinEra = GameInfo.Eras[row.MinEra].ID, MaxEra = GameInfo.Eras[row.MaxEra].ID,
		PrereqType = row.PrereqStage, PrereqTurns = FN.Turns(row.PrereqTurns),
		PolicyID = GameInfoTypes[row.PolicyType],
		GoldenAgeTurns = row.GoldenAgeTurns or 0,
		UniqueUnits = {}, -- { Unit = unit ID, Replaces = unit ID }, from Policy_UnitClassReplacements (FN_Perks.sql)
		Groups = {}, GroupByID = {},
	}
	table.insert(FN.Stages, s)
	FN.StageByType[s.Type] = s
end
local tStageByPolicy = {}
for _, s in ipairs(FN.Stages) do tStageByPolicy[GameInfo.Policies[s.PolicyID].Type] = s end
for row in GameInfo.Policy_UnitClassReplacements() do
	local s = tStageByPolicy[row.PolicyType]
	local new, old = GameInfo.UnitClasses[row.ReplacementUnitClassType], GameInfo.UnitClasses[row.ReplacedUnitClassType]
	if s and new and old then
		table.insert(s.UniqueUnits, { Unit = GameInfoTypes[new.DefaultUnit], Replaces = GameInfoTypes[old.DefaultUnit] })
	end
end
for row in GameInfo.FormableNation_ClaimGroups() do
	local s = FN.StageByType[row.FormableType]
	if s then
		local g = { ID = row.GroupID, Need = row.NumRequired, Desc = row.Description, Claims = {} }
		table.insert(s.Groups, g)
		s.GroupByID[g.ID] = g
	end
end
for row in GameInfo.FormableNation_Claims() do
	local s = FN.StageByType[row.FormableType]
	local g = s and s.GroupByID[row.GroupID]
	if g then
		table.insert(g.Claims, {
			MinorID = row.MinorCivType and GameInfoTypes[row.MinorCivType],
			CivID = row.CivilizationType and GameInfoTypes[row.CivilizationType],
			Mode = row.Mode,
		})
	end
end
table.sort(FN.Stages, function(a, b)
	if a.Chain ~= b.Chain then return a.Chain < b.Chain end
	return a.Stage < b.Stage
end)

------------------------------------------------------------------------------
-- Claim targets
------------------------------------------------------------------------------
function FN.FindClaimPlayer(claim)
	if claim.MinorID then
		for i = FN.MAX_MAJOR, FN.MAX_CIV - 1 do
			local p = Players[i]
			if p and p:IsEverAlive() and p:IsMinorCiv() and p:GetMinorCivType() == claim.MinorID then return p end
		end
	elseif claim.CivID then
		for i = 0, FN.MAX_MAJOR - 1 do
			local p = Players[i]
			if p and p:IsEverAlive() and p:GetCivilizationType() == claim.CivID then return p end
		end
	end
	return nil
end

-- A claim targets its people's original capital, wherever it has ended up.
function FN.FindClaimCity(pTarget)
	local pPlot = pTarget:GetOriginalCapitalPlot()
	return pPlot and pPlot:GetPlotCity()
end

function FN.ClaimName(claim)
	if claim.MinorID then return L(GameInfo.MinorCivilizations[claim.MinorID].Description) end
	return L("TXT_KEY_FN_CLAIM_CAPITAL_OF", GameInfo.Civilizations[claim.CivID].ShortDescription)
end

function FN.PlayerName(p)
	if p:IsMinorCiv() then return L(GameInfo.MinorCivilizations[p:GetMinorCivType()].Description) end
	return L(p:GetCivilizationShortDescriptionKey())
end

function FN.HasStage(pPlayer, s) return pPlayer:HasPolicy(s.PolicyID) end

-- Returns bMet, sState, bNeedsAnnex, pTarget, extra
function FN.EvaluateClaim(pPlayer, claim)
	local pTarget = FN.FindClaimPlayer(claim)
	if not pTarget then return false, "ABSENT" end
	local pCity = FN.FindClaimCity(pTarget)
	if not pCity then return false, "LOST", false, pTarget end

	local iPlayer = pPlayer:GetID()
	if pCity:GetOwner() == iPlayer then return true, "OWNED", false, pTarget end
	if claim.Mode == "OWN" then
		return false, (pCity:GetOwner() == pTarget:GetID()) and "NOT_HELD" or "LOST", false, pTarget
	end
	if pCity:GetOwner() ~= pTarget:GetID() or not pTarget:IsAlive() then return false, "LOST", false, pTarget end

	if pTarget:IsMinorCiv() then
		if Teams[pPlayer:GetTeam()]:IsAtWar(pTarget:GetTeam()) then return false, "AT_WAR", false, pTarget end
		local bBound = FN.IsBound and FN.IsBound(iPlayer, pTarget:GetID())
		if bBound then return true, "BOUND", claim.Mode == "ABSORB", pTarget end
		if pTarget:IsMarried(iPlayer) then return true, "MARRIED", false, pTarget end
		if not pTarget:IsAllies(iPlayer) then return false, "NOT_ALLIED", false, pTarget end
		if claim.Mode == "ALLY" then return true, "ALLIED", false, pTarget end
		local iTurns = pTarget:GetAlliedTurns()
		if iTurns >= FN.UNION_TURNS then return true, "ALLIED", claim.Mode == "ABSORB", pTarget end
		return false, "ALLIED_SHORT", false, pTarget, iTurns
	end

	-- Major civilization: a vassal satisfies a union or recognition claim; annexation needs the city itself.
	if claim.Mode ~= "ABSORB" and Teams[pTarget:GetTeam()]:IsVassal(pPlayer:GetTeam()) then
		return true, "VASSAL", false, pTarget
	end
	return false, "NOT_HELD", false, pTarget
end

function FN.HighestStageInChain(pPlayer, sChain)
	local best = nil
	for _, s in ipairs(FN.Stages) do
		if s.Chain == sChain and FN.HasStage(pPlayer, s) and (not best or s.Stage > best.Stage) then best = s end
	end
	return best
end

function FN.TurnsHeld(pPlayer, s)
	local iTurn = FN.GetN("T_" .. pPlayer:GetID() .. "_" .. s.Type)
	if iTurn == 0 then return 0 end
	return Game.GetGameTurn() - iTurn
end

-- r.Possible: can still happen in this game. r.Ready: can be proclaimed now. r.Lines: requirement report.
function FN.EvaluateStage(pPlayer, s)
	local r = { Possible = true, Ready = true, Lines = {}, Annex = {}, Cost = 0 }
	local iPlayer = pPlayer:GetID()

	r.Formed = FN.HasStage(pPlayer, s)
	local pHighest = FN.HighestStageInChain(pPlayer, s.Chain)
	r.Superseded = (not r.Formed) and pHighest ~= nil and pHighest.Stage >= s.Stage

	local iEra = pPlayer:GetCurrentEra()
	if iEra > s.MaxEra and not r.Formed then r.Possible = false; r.Expired = true end
	table.insert(r.Lines, { Ok = iEra >= s.MinEra, Text = L("TXT_KEY_FN_REQ_ERA", GameInfo.Eras[s.MinEra].Description) })
	if iEra < s.MinEra then r.Ready = false end

	if s.PrereqType then
		local pPrereq = FN.StageByType[s.PrereqType]
		if not FN.HasStage(pPlayer, pPrereq) then
			table.insert(r.Lines, { Ok = false, Text = L("TXT_KEY_FN_REQ_PREREQ_MISSING", pPrereq.Title) })
			r.Ready = false
			if iEra > pPrereq.MaxEra then r.Possible = false; r.Expired = true end
		elseif pPrereq.IsUnion and FN.IntegrationReport then
			-- Deepening a union: every partner must have stayed integrated long enough.
			local bOk, tLines = FN.IntegrationReport(pPlayer, pPrereq, s.PrereqTurns)
			for _, line in ipairs(tLines) do table.insert(r.Lines, line) end
			if not bOk then r.Ready = false end
		else
			local iHeld = FN.TurnsHeld(pPlayer, pPrereq)
			local bOk = iHeld >= s.PrereqTurns
			table.insert(r.Lines, { Ok = bOk, Text = L("TXT_KEY_FN_REQ_PREREQ", pPrereq.Title, s.PrereqTurns, iHeld) })
			if not bOk then r.Ready = false end
		end
	end

	local bHappy = not pPlayer:IsEmpireUnhappy()
	table.insert(r.Lines, { Ok = bHappy, Text = L("TXT_KEY_FN_REQ_HAPPY") })
	if not bHappy then r.Ready = false end

	for _, g in ipairs(s.Groups) do
		local tFree, tAnnex, iPresent, tClaimLines = {}, {}, 0, {}
		for _, claim in ipairs(g.Claims) do
			local bMet, sState, bAnnex, pTarget, iExtra = FN.EvaluateClaim(pPlayer, claim)
			if sState ~= "ABSENT" then iPresent = iPresent + 1 end
			if bMet then
				if bAnnex then table.insert(tAnnex, pTarget) else table.insert(tFree, pTarget) end
			end
			local sStateText
			if sState == "ALLIED_SHORT" then
				sStateText = L("TXT_KEY_FN_CLAIM_ALLIED_TURNS", iExtra, FN.UNION_TURNS)
			elseif bAnnex then
				sStateText = L("TXT_KEY_FN_CLAIM_" .. sState) .. ", " .. L("TXT_KEY_FN_CLAIM_WILL_ANNEX")
			else
				sStateText = L("TXT_KEY_FN_CLAIM_" .. sState)
			end
			table.insert(tClaimLines, { Ok = bMet, Indent = true,
				Text = L("TXT_KEY_FN_CLAIM_LINE", FN.ClaimName(claim), L("TXT_KEY_FN_MODE_" .. claim.Mode), sStateText) })
		end
		local bGroupOk = (#tFree + #tAnnex) >= g.Need
		table.insert(r.Lines, { Ok = bGroupOk, Text = L("TXT_KEY_FN_REQ_GROUP", g.Desc, g.Need) })
		for _, line in ipairs(tClaimLines) do table.insert(r.Lines, line) end
		if iPresent < g.Need then r.Possible = false; r.MissingGroup = g.Desc end
		if not bGroupOk then
			r.Ready = false
		else
			-- Annex only as many as the group still needs beyond claims that are already free.
			for i = 1, g.Need - #tFree do
				if tAnnex[i] then table.insert(r.Annex, tAnnex[i]) end
			end
		end
	end

	for _, pMinor in ipairs(r.Annex) do r.Cost = r.Cost + pMinor:GetBuyoutCost(iPlayer) end
	if r.Cost > 0 then
		local bOk = pPlayer:GetGold() >= r.Cost
		table.insert(r.Lines, { Ok = bOk, Text = L("TXT_KEY_FN_REQ_GOLD", r.Cost, pPlayer:GetGold()) })
		if not bOk then r.Ready = false end
	end

	if r.Formed or r.Superseded or not r.Possible then r.Ready = false end
	return r
end

------------------------------------------------------------------------------
-- Identity (civ names). PreGame setters take text keys, so names follow the player's language.
------------------------------------------------------------------------------
function FN.IdentityStage(pPlayer)
	local best = nil
	for _, s in ipairs(FN.Stages) do
		if s.Desc and FN.HasStage(pPlayer, s) and (not best or s.Tier > best.Tier or (s.Tier == best.Tier and s.Stage > best.Stage)) then
			best = s
		end
	end
	return best
end

function FN.ApplyIdentity(pPlayer)
	local iPlayer = pPlayer:GetID()
	local s = FN.IdentityStage(pPlayer)
	if s then
		if FN.GetN("ORIG_" .. iPlayer) == 0 then
			FN.Set("ORIG_" .. iPlayer, 1)
			FN.Set("ORIG_D_" .. iPlayer, PreGame.GetCivilizationDescription(iPlayer) or "")
			FN.Set("ORIG_S_" .. iPlayer, PreGame.GetCivilizationShortDescription(iPlayer) or "")
			FN.Set("ORIG_A_" .. iPlayer, PreGame.GetCivilizationAdjective(iPlayer) or "")
		end
		PreGame.SetCivilizationDescription(iPlayer, s.Desc)
		PreGame.SetCivilizationShortDescription(iPlayer, s.Short)
		PreGame.SetCivilizationAdjective(iPlayer, s.Adj)
	elseif FN.GetN("ORIG_" .. iPlayer) == 1 then
		PreGame.SetCivilizationDescription(iPlayer, FN.Get("ORIG_D_" .. iPlayer) or "")
		PreGame.SetCivilizationShortDescription(iPlayer, FN.Get("ORIG_S_" .. iPlayer) or "")
		PreGame.SetCivilizationAdjective(iPlayer, FN.Get("ORIG_A_" .. iPlayer) or "")
	end
end

------------------------------------------------------------------------------
-- Notifications to every human who knows the subject
------------------------------------------------------------------------------
function FN.NotifyKnown(pSubject, sText, sSummary, iX, iY)
	if not iX then
		local pCapital = pSubject:GetCapitalCity()
		iX, iY = -1, -1
		if pCapital then iX, iY = pCapital:GetX(), pCapital:GetY() end
	end
	local iSubjectTeam = pSubject:GetTeam()
	for i = 0, FN.MAX_MAJOR - 1 do
		local p = Players[i]
		if p and p:IsAlive() and p:IsHuman() and (i == pSubject:GetID() or Teams[p:GetTeam()]:IsHasMet(iSubjectTeam)) then
			p:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, sText, sSummary, iX, iY)
		end
	end
end

function FN.Notify(pPlayer, sText, sSummary, iX, iY)
	if pPlayer:IsHuman() then
		pPlayer:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, sText, sSummary, iX or -1, iY or -1)
	end
end

------------------------------------------------------------------------------
-- Formation and dissolution
------------------------------------------------------------------------------
local function AnnexMinor(pPlayer, pMinor)
	-- Military units change sides; the rest disband (as in the engine's own City-State buyout).
	local tUnits, tRespawn = {}, {}
	for pUnit in pMinor:Units() do table.insert(tUnits, pUnit) end
	for _, pUnit in ipairs(tUnits) do
		if pUnit:IsCombatUnit() then
			table.insert(tRespawn, { Type = pUnit:GetUnitType(), X = pUnit:GetX(), Y = pUnit:GetY() })
		end
		pUnit:Kill(false, -1)
	end
	local tCities = {}
	for pCity in pMinor:Cities() do table.insert(tCities, pCity) end
	for _, pCity in ipairs(tCities) do
		pPlayer:AcquireCity(pCity, false, true) -- a gift, not conquest: the engine's peaceful buyout path
	end
	for _, u in ipairs(tRespawn) do
		local pNew = pPlayer:InitUnit(u.Type, u.X, u.Y)
		if pNew then pNew:FinishMoves() end
	end
end

local function RemoveStage(pPlayer, s)
	pPlayer:SetHasPolicy(s.PolicyID, false)
	if s.IsUnion and FN.OnUnionEnded then FN.OnUnionEnded(pPlayer, s) end
end

function FN.FormStage(pPlayer, s)
	local r = FN.EvaluateStage(pPlayer, s)
	if not r.Ready then return false end
	local iPlayer = pPlayer:GetID()
	local sLeader = pPlayer:GetName()

	-- One identity at a time: the new stage supersedes every earlier one this player holds.
	for _, o in ipairs(FN.Stages) do
		if o ~= s and FN.HasStage(pPlayer, o) then RemoveStage(pPlayer, o) end
	end
	for _, pMinor in ipairs(r.Annex) do
		pPlayer:ChangeGold(-pMinor:GetBuyoutCost(iPlayer))
		AnnexMinor(pPlayer, pMinor)
	end
	pPlayer:SetHasPolicy(s.PolicyID, true, true)
	FN.Set("T_" .. iPlayer .. "_" .. s.Type, Game.GetGameTurn())
	if s.GoldenAgeTurns > 0 then pPlayer:ChangeGoldenAgeTurns(s.GoldenAgeTurns) end
	if s.IsUnion and FN.OnUnionFormed then FN.OnUnionFormed(pPlayer, s) end
	FN.ApplyIdentity(pPlayer)

	FN.NotifyKnown(pPlayer, L("TXT_KEY_FN_NOTIFY_FORMED", sLeader, s.Title), L("TXT_KEY_FN_NOTIFY_FORMED_S", s.Title))
	FN.Log("player %d (%s) proclaimed %s; annexed %d City-State(s) for %d gold", iPlayer, sLeader, s.Type, #r.Annex, r.Cost)
	if FN.DrawOverlay then FN.DrawOverlay() end
	return true
end

function FN.DissolveStage(pPlayer, s)
	RemoveStage(pPlayer, s)
	FN.ApplyIdentity(pPlayer)
	FN.NotifyKnown(pPlayer, L("TXT_KEY_FN_NOTIFY_DISSOLVED", s.Title, pPlayer:GetName()), L("TXT_KEY_FN_NOTIFY_DISSOLVED_S", s.Title))
	FN.Log("player %d's %s dissolved", pPlayer:GetID(), s.Type)
	if FN.DrawOverlay then FN.DrawOverlay() end
end

-- Notify humans once when a stage becomes available; AIs proclaim as soon as they can.
function FN.ConsiderStages(pPlayer)
	local iPlayer = pPlayer:GetID()
	local iCiv = pPlayer:GetCivilizationType()
	for _, s in ipairs(FN.Stages) do
		if s.CivID == iCiv then
			local r = FN.EvaluateStage(pPlayer, s)
			if r.Ready then
				if pPlayer:IsHuman() then
					local sKey = "N_" .. iPlayer .. "_" .. s.Type
					if FN.GetN(sKey) == 0 then
						FN.Set(sKey, Game.GetGameTurn())
						FN.Notify(pPlayer, L("TXT_KEY_FN_NOTIFY_AVAILABLE", s.Title), L("TXT_KEY_FN_NOTIFY_AVAILABLE_S", s.Title))
					end
				else
					FN.FormStage(pPlayer, s)
				end
			end
		end
	end
end
