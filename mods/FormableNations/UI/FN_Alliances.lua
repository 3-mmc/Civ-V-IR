-- Formable Nations: alliances (design: "Alliances and defence pacts").
-- An alliance is an organisation of Depth ALLIANCE whose charter sets its terms:
--   Obligation  DEFENCE (an attack on one is an attack on all), FULL (also members' own wars), CONSULT (a call that may be refused)
--   Scope       GLOBAL, or REGIONAL (only aggressors whose capital is near the attacked member's)
--   NoSeparatePeace, Burden (NONE / TARGET / TRIBUTE), Hegemonic (the leader's wars call members in; leaving only by referendum)
-- When war is declared (GameEvents.DeclareWar), the obligations are queued and resolved in the next player's turn
-- processing rather than inside the engine's declaration. AI members answer by their cohesion; humans get a call to arms
-- to honour or decline on the Organisations tab. Answering or refusing a binding call moves the member's credibility,
-- which feeds the alliance cohesion that also decides exit referendums.
-- Save keys (per alliance o, member p, enemy team t):
--   CA_<o>_<p> pending call: enemy team + 1     CAT_<o>_<p> turn of the call     CAB_<o>_<p> 1 if the call is binding
--   OCR_<o>_<p> credibility                      AW_<o>_<t> member + 1 whose war the alliance is fighting (no separate peace)
--   PN_<o> custom pact name                      PT_<o>_<Term> custom pact term
local L = FN.L
local S = FN.S

FN.CHARTER_OPTIONS = {
	Obligation = { "DEFENCE", "FULL", "CONSULT" },
	Scope = { "GLOBAL", "REGIONAL" },
	Burden = { "NONE", "TARGET", "TRIBUTE" },
	NoSeparatePeace = { false, true },
	Hegemonic = { false, true },
	OpenBorders = { true, false },
}
FN.CHARTER_TERMS = { "Obligation", "Scope", "NoSeparatePeace", "Burden", "Hegemonic", "OpenBorders" }

local function K(sPrefix, o, i) return sPrefix .. "_" .. o.Type .. "_" .. i end

function FN.Alliances()
	local t = {}
	for _, o in ipairs(FN.Orgs) do if o.Depth == "ALLIANCE" then table.insert(t, o) end end
	return t
end

------------------------------------------------------------------------------
-- Custom pacts: name and terms live in save data
------------------------------------------------------------------------------
local function Encode(v) if v == true then return "1" elseif v == false then return "0" end return v end
local function Decode(sTerm, v)
	if type(FN.CHARTER_OPTIONS[sTerm][1]) == "boolean" then return v == "1" end
	return v
end

local tDefaults = {}
for _, o in ipairs(FN.Orgs) do
	if o.Custom then
		tDefaults[o.Type] = { Title = o.Title }
		for _, sTerm in ipairs(FN.CHARTER_TERMS) do tDefaults[o.Type][sTerm] = o[sTerm] end
	end
end

local function LoadCustom(o)
	local sName = FN.Get("PN_" .. o.Type)
	if FN.OrgActive(o) and sName and sName ~= "" and sName ~= 0 then
		o.Title = sName
		for _, sTerm in ipairs(FN.CHARTER_TERMS) do
			local v = FN.Get("PT_" .. o.Type .. "_" .. sTerm)
			if v ~= nil and v ~= "" then o[sTerm] = Decode(sTerm, v) end
		end
	else
		for k, v in pairs(tDefaults[o.Type]) do o[k] = v end
	end
end
for _, o in ipairs(FN.Orgs) do if o.Custom then LoadCustom(o) end end

-- The first custom slot free for a new pact, or nil.
function FN.FreePactSlot()
	for _, o in ipairs(FN.Orgs) do
		if o.Custom and not FN.OrgActive(o) then return o end
	end
end

-- tCharter: { Name = string, Obligation = .., Scope = .., ... }. Founds the pact if enough members are willing.
function FN.FoundPact(pLeader, tCharter)
	local o = FN.FreePactSlot()
	if not o or not tCharter.Name or tCharter.Name == "" then return false end
	o.Title = tCharter.Name
	for _, sTerm in ipairs(FN.CHARTER_TERMS) do o[sTerm] = tCharter[sTerm] end
	if not FN.FoundOrg(o, pLeader) then
		LoadCustom(o) -- back to the defaults
		return false
	end
	FN.Set("PN_" .. o.Type, tCharter.Name)
	for _, sTerm in ipairs(FN.CHARTER_TERMS) do FN.Set("PT_" .. o.Type .. "_" .. sTerm, Encode(tCharter[sTerm])) end
	return true
end

local DissolveOrg = FN.DissolveOrg
function FN.DissolveOrg(o, ...)
	DissolveOrg(o, ...)
	if o.Custom then
		FN.Set("PN_" .. o.Type, "")
		LoadCustom(o)
	end
end

-- Hegemonic alliances can only be left by referendum (FN_Organisations); their leader may always leave.
function FN.CanLeaveOrg(o, p)
	return not (o.Hegemonic and p:GetID() ~= FN.OrgLeader(o))
end

-- Charter summary for the panel.
function FN.CharterText(o)
	local t = {
		L("TXT_KEY_FN_CHARTER_OBLIGATION_" .. o.Obligation),
		L("TXT_KEY_FN_CHARTER_SCOPE_" .. o.Scope, S.ALLIANCE_REGION_TILES),
		L(o.NoSeparatePeace and "TXT_KEY_FN_CHARTER_PEACE_JOINT" or "TXT_KEY_FN_CHARTER_PEACE_FREE"),
		L("TXT_KEY_FN_CHARTER_BURDEN_" .. o.Burden, S.BURDEN_TARGET_PERCENT, S.TRIBUTE_GOLD_PER_ERA),
		L(o.Hegemonic and "TXT_KEY_FN_CHARTER_HEGEMONIC" or "TXT_KEY_FN_CHARTER_EQUALS"),
		L(o.OpenBorders and "TXT_KEY_FN_CHARTER_BORDERS_OPEN" or "TXT_KEY_FN_CHARTER_BORDERS_CLOSED"),
		L("TXT_KEY_FN_CHARTER_NO_WAR"),
	}
	return table.concat(t, "[NEWLINE]")
end

------------------------------------------------------------------------------
-- Cohesion terms specific to alliances (called from FN.OrgEquilibrium)
------------------------------------------------------------------------------
local function CapitalDistance(pA, pB)
	local a, b = pA:GetCapitalCity(), pB:GetCapitalCity()
	if not a or not b then return 9999 end
	return Map.PlotDistance(a:GetX(), a:GetY(), b:GetX(), b:GetY())
end

-- The strongest outside major near p whose military outmatches p's, or nil.
local function Threat(p, tIsMember)
	local pBest, iBest = nil, p:GetMilitaryMight()
	for i = 0, FN.MAX_MAJOR - 1 do
		local q = Players[i]
		if q and q:IsAlive() and i ~= p:GetID() and not (tIsMember and tIsMember[i]) and CapitalDistance(p, q) <= S.THREAT_TILES then
			local iMight = q:GetMilitaryMight()
			if iMight > iBest then pBest, iBest = q, iMight end
		end
	end
	return pBest
end

-- Would p and pLeader both face the same stronger neighbour?
function FN.CommonThreat(p, pLeader)
	local pThreat = Threat(p)
	return pThreat ~= nil and pThreat:GetID() ~= pLeader:GetID() and Threat(pLeader) == pThreat
end

function FN.Credibility(o, iP) return FN.GetN(K("OCR", o, iP)) end

function FN.AllianceTerms(o, p, Add)
	local iP = p:GetID()
	local tMembers = FN.Members(o)
	local tIsMember = {}
	for _, q in ipairs(tMembers) do tIsMember[q:GetID()] = true end

	local iCredit = FN.Credibility(o, iP)
	if iCredit ~= 0 then Add("CREDIBILITY", math.max(S.TERM_CREDIT_MIN, math.min(S.TERM_CREDIT_MAX, iCredit))) end
	if Threat(p, tIsMember) then Add("THREAT", S.TERM_THREAT) end

	if o.Burden == "TARGET" then
		local iSum, iCount = 0, 0
		for _, q in ipairs(tMembers) do
			if not q:IsMinorCiv() then iSum, iCount = iSum + q:GetMilitaryMight(), iCount + 1 end
		end
		if iCount > 1 then
			local bMet = p:GetMilitaryMight() * 100 >= (iSum / iCount) * S.BURDEN_TARGET_PERCENT
			Add("BURDEN_TARGET", bMet and S.TERM_TARGET_MET or S.TERM_TARGET_MISSED)
		end
	elseif o.Burden == "TRIBUTE" and iP ~= FN.OrgLeader(o) then
		Add("BURDEN_TRIBUTE", S.TERM_TRIBUTE)
	end
end

function FN.TributeGold(p) return math.max(1, math.floor(S.TRIBUTE_GOLD_PER_ERA * (p:GetCurrentEra() + 1) * FN.GOLD_PERCENT / 100)) end

-- Per turn, in the leader's turn (from ProcessOrg).
function FN.ProcessAllianceEffects(o)
	local iLeader = FN.OrgLeader(o)
	local pLeader = Players[iLeader]
	for _, p in ipairs(FN.Members(o)) do
		local iP = p:GetID()
		if not p:IsMinorCiv() then
			-- Credibility fades back toward neutral.
			local iCredit = FN.Credibility(o, iP)
			if iCredit > 0 then FN.Set(K("OCR", o, iP), iCredit - 1) elseif iCredit < 0 then FN.Set(K("OCR", o, iP), iCredit + 1) end
			if o.Burden == "TRIBUTE" and iP ~= iLeader then
				local iGold = math.min(p:GetGold(), FN.TributeGold(p))
				if iGold > 0 then p:ChangeGold(-iGold); pLeader:ChangeGold(iGold) end
			end
		end
	end
	-- The war a no-separate-peace alliance is fighting ends when the member who started it is at peace.
	if o.NoSeparatePeace then
		for t = 0, FN.MAX_CIV - 1 do
			local iLead = FN.GetN(K("AW", o, t)) - 1
			if iLead >= 0 then
				local pLead = Players[iLead]
				if not pLead or not pLead:IsAlive() or not FN.IsMember(o, iLead) or not Teams[pLead:GetTeam()]:IsAtWar(t) then
					FN.Set(K("AW", o, t), 0)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Calls to arms
------------------------------------------------------------------------------
local g_tWars = {} -- declarations queued this turn: { Aggressor = player, Target = team }

function FN.OnDeclareWar(iOriginatingPlayer, iTeam, bAggressor)
	if iOriginatingPlayer and iOriginatingPlayer >= 0 then
		table.insert(g_tWars, { Aggressor = iOriginatingPlayer, Target = iTeam })
	end
end

local function TeamMembers(o, iTeam)
	local t = {}
	for _, p in ipairs(FN.Members(o)) do if p:GetTeam() == iTeam then table.insert(t, p) end end
	return t
end

local function AtWar(p, iTeam) return Teams[p:GetTeam()]:IsAtWar(iTeam) end

-- Declares war for member p (an AI or a human who honoured the call) as a defensive-pact war.
local function JoinWar(o, p, iEnemyTeam)
	if AtWar(p, iEnemyTeam) or p:GetTeam() == iEnemyTeam then return true end
	if not Teams[p:GetTeam()]:CanDeclareWar(iEnemyTeam) then return false end
	Teams[p:GetTeam()]:DeclareWar(iEnemyTeam, true, p:GetID())
	return true
end

local function Credit(o, p, iDelta)
	FN.Set(K("OCR", o, p:GetID()), FN.Credibility(o, p:GetID()) + iDelta)
end

-- pCaller: the member whose war it is. bBinding: false for CONSULT, where refusing costs nothing.
local function CallToArms(o, pCaller, iEnemyTeam, bBinding)
	local pEnemyLead = nil
	for i = 0, FN.MAX_CIV - 1 do
		local q = Players[i]
		if q and q:IsAlive() and q:GetTeam() == iEnemyTeam then pEnemyLead = q; break end
	end
	if o.NoSeparatePeace and FN.GetN(K("AW", o, iEnemyTeam)) == 0 then FN.Set(K("AW", o, iEnemyTeam), pCaller:GetID() + 1) end
	for _, p in ipairs(FN.Members(o)) do
		if p:GetTeam() ~= pCaller:GetTeam() and p:GetTeam() ~= iEnemyTeam and not AtWar(p, iEnemyTeam) then
			if p:IsMinorCiv() then
				if bBinding then JoinWar(o, p, iEnemyTeam) end
			elseif p:IsHuman() then
				FN.Set(K("CA", o, p:GetID()), iEnemyTeam + 1)
				FN.Set(K("CAT", o, p:GetID()), Game.GetGameTurn())
				FN.Set(K("CAB", o, p:GetID()), bBinding and 1 or 0)
				FN.Notify(p, L("TXT_KEY_FN_NOTIFY_CALL_TO_ARMS", FN.PlayerName(pCaller), FN.OrgName(o), pEnemyLead and FN.PlayerName(pEnemyLead) or "?"),
					L("TXT_KEY_FN_NOTIFY_CALL_TO_ARMS_S", FN.OrgName(o)))
			else
				local bHonour = FN.OrgCohesion(o, p:GetID()) >= S.ALLIANCE_AI_HONOUR and (bBinding or p:IsDoF(pCaller:GetID()))
				if bHonour and JoinWar(o, p, iEnemyTeam) then
					if bBinding then Credit(o, p, S.CREDIT_HONOUR) end
					FN.Log("%s: %d honours %d's call against team %d", o.Type, p:GetID(), pCaller:GetID(), iEnemyTeam)
				else
					if bBinding then Credit(o, p, S.CREDIT_DECLINE) end
					FN.NotifyKnown(p, L("TXT_KEY_FN_NOTIFY_CALL_DECLINED", FN.PlayerName(p), FN.OrgName(o), FN.PlayerName(pCaller)),
						L("TXT_KEY_FN_NOTIFY_CALL_DECLINED_S", FN.PlayerName(p)))
					FN.Log("%s: %d declines %d's call against team %d", o.Type, p:GetID(), pCaller:GetID(), iEnemyTeam)
				end
			end
		end
	end
end

local function InScope(o, pMember, pAggressor)
	if o.Scope ~= "REGIONAL" then return true end
	return CapitalDistance(pMember, pAggressor) <= S.ALLIANCE_REGION_TILES
end

-- Resolve queued declarations. Joining a war may queue more (alliances answering alliances); they wait for the next pass.
function FN.ProcessAllianceWars()
	if #g_tWars == 0 then return end
	local tWars = g_tWars
	g_tWars = {}
	for _, w in ipairs(tWars) do
		local pAggressor = Players[w.Aggressor]
		if pAggressor then
			local iAggTeam = pAggressor:GetTeam()
			for _, o in ipairs(FN.Alliances()) do
				if FN.OrgActive(o) then
					local tDefenders = TeamMembers(o, w.Target)
					local bAggMember = FN.IsMember(o, w.Aggressor)
					-- Defence: a member was attacked by an outsider.
					if #tDefenders > 0 and not bAggMember then
						local pDefender = tDefenders[1]
						if InScope(o, pDefender, pAggressor) then
							CallToArms(o, pDefender, iAggTeam, o.Obligation ~= "CONSULT")
						end
					end
					-- Offence: a member attacked an outsider. Binding under FULL, or under a hegemon's own war.
					if bAggMember and #tDefenders == 0 then
						if o.Obligation == "FULL" or (o.Hegemonic and w.Aggressor == FN.OrgLeader(o)) then
							CallToArms(o, pAggressor, w.Target, true)
						elseif o.Obligation == "CONSULT" then
							CallToArms(o, pAggressor, w.Target, false)
						end
					end
				end
			end
		end
	end
end

-- A human's answer. bHonour: join the war; otherwise decline (costs credibility if the call was binding).
function FN.AnswerCall(o, p, bHonour)
	local iP = p:GetID()
	local iEnemy = FN.GetN(K("CA", o, iP)) - 1
	if iEnemy < 0 then return false end
	local bBinding = FN.GetN(K("CAB", o, iP)) == 1
	FN.Set(K("CA", o, iP), 0)
	if bHonour then
		if not JoinWar(o, p, iEnemy) then return false end
		if bBinding then Credit(o, p, S.CREDIT_HONOUR) end
	elseif bBinding then
		Credit(o, p, S.CREDIT_DECLINE)
	end
	FN.Log("%s: %d %s a call against team %d", o.Type, iP, bHonour and "honours" or "declines", iEnemy)
	return true
end

function FN.PendingCall(o, iP)
	local iEnemy = FN.GetN(K("CA", o, iP)) - 1
	if iEnemy < 0 then return nil end
	return iEnemy, FN.GetN(K("CAT", o, iP)) + FN.Turns(S.ALLIANCE_CALL_TURNS) - Game.GetGameTurn()
end

-- Unanswered calls lapse as declined; called in each human's turn.
function FN.ExpireCalls(p)
	for _, o in ipairs(FN.Alliances()) do
		local iEnemy, iLeft = FN.PendingCall(o, p:GetID())
		if iEnemy and (iLeft <= 0 or not FN.IsMember(o, p:GetID()) or AtWar(p, iEnemy)) then
			FN.AnswerCall(o, p, AtWar(p, iEnemy))
		end
	end
end

------------------------------------------------------------------------------
-- No separate peace (GameEvents.PlayerCanMakePeace, peace treaties in deals)
------------------------------------------------------------------------------
function FN.AllianceAllowsPeace(iPlayer, iTeam)
	for _, o in ipairs(FN.Alliances()) do
		if o.NoSeparatePeace and FN.IsMember(o, iPlayer) then
			local iLead = FN.GetN(K("AW", o, iTeam)) - 1
			if iLead >= 0 and iLead ~= iPlayer then
				local pLead = Players[iLead]
				if pLead and pLead:IsAlive() and FN.IsMember(o, iLead) and Teams[pLead:GetTeam()]:IsAtWar(iTeam) then return false end
			end
		end
	end
	return true
end

-- Display name: a custom pact's own name, else its title key.
function FN.OrgName(o) return L(o.Title) end
