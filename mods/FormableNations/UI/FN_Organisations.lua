-- Formable Nations: international organisations (design: "International organisations, by depth").
-- Save keys: OF_<org> founded turn (0 = not active), OL_<org> founder (leader) player,
--            OM_<org>_<player> member (1/0), OI_<org>_<player> pending invitation for a human (turn).
local L = FN.L

FN.Orgs = {}
FN.OrgByType = {}
for row in GameInfo.FormableNation_Organisations() do
	local o = {
		Type = row.Type, Depth = row.Depth, Title = row.Title, Help = row.Help, Quote = row.Quote,
		MinEra = GameInfo.Eras[row.MinEra].ID, MaxEra = row.MaxEra and GameInfo.Eras[row.MaxEra].ID,
		MinMembers = row.MinMembers,
		RequiresCoast = (row.RequiresCoast == true or row.RequiresCoast == 1),
		ResourceID = row.ResourceType and GameInfoTypes[row.ResourceType], MinResource = row.MinResource,
		TradeRouteGold = row.TradeRouteGold, ResourceGold = row.ResourceGold, MinorInfluence = row.MinorInfluence,
		OpenBorders = (row.OpenBorders == true or row.OpenBorders == 1),
		PolicyID = row.PolicyType and GameInfoTypes[row.PolicyType],
		Civs = {}, Minors = {}, HasCivList = false, HasMinorList = false,
	}
	table.insert(FN.Orgs, o)
	FN.OrgByType[o.Type] = o
end
for row in GameInfo.FormableNation_OrganisationMembers() do
	local o = FN.OrgByType[row.OrganisationType]
	if o then
		if row.CivilizationType then o.Civs[GameInfoTypes[row.CivilizationType]] = true; o.HasCivList = true end
		if row.MinorCivType then o.Minors[GameInfoTypes[row.MinorCivType]] = true; o.HasMinorList = true end
	end
end

function FN.OrgActive(o) return FN.GetN("OF_" .. o.Type) > 0 end
function FN.OrgLeader(o) return FN.GetN("OL_" .. o.Type) end
function FN.IsMember(o, iPlayer) return FN.OrgActive(o) and FN.GetN("OM_" .. o.Type .. "_" .. iPlayer) == 1 end

function FN.Members(o)
	local t = {}
	if not FN.OrgActive(o) then return t end
	for i = 0, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and p:IsAlive() and FN.GetN("OM_" .. o.Type .. "_" .. i) == 1 then table.insert(t, p) end
	end
	return t
end

------------------------------------------------------------------------------
-- Eligibility and willingness
------------------------------------------------------------------------------
function FN.OrgEligible(o, p)
	if not p or not p:IsAlive() or p:IsBarbarian() then return false end
	if p:IsMinorCiv() then
		if o.HasMinorList then
			if not o.Minors[p:GetMinorCivType()] then return false end
		elseif not o.ResourceID then
			return false
		end
	else
		if o.HasCivList and not o.Civs[p:GetCivilizationType()] then return false end
	end
	if o.RequiresCoast then
		local pCapital = p:GetCapitalCity()
		if not pCapital or not pCapital:IsCoastal(10) then return false end
	end
	if o.ResourceID and p:GetNumResourceTotal(o.ResourceID, false) < o.MinResource then return false end
	return true
end

local function Hostile(pA, pB)
	if Teams[pA:GetTeam()]:IsAtWar(pB:GetTeam()) then return true end
	if not pA:IsMinorCiv() and not pB:IsMinorCiv() then
		return pA:IsDenouncingPlayer(pB:GetID()) or pB:IsDenouncingPlayer(pA:GetID())
	end
	return false
end

local function ReligionOf(p)
	local pCapital = p:GetCapitalCity()
	return pCapital and pCapital:GetReligiousMajority() or -1
end

-- Would p (City-State or AI major) join an organisation led by pLeader?
function FN.OrgWilling(o, p, pLeader)
	if Hostile(p, pLeader) then return false end
	if p:IsMinorCiv() then return p:IsFriends(pLeader:GetID()) end
	if not Teams[p:GetTeam()]:IsHasMet(pLeader:GetTeam()) then return false end
	if o.Depth == "FUNCTIONAL" then return true end -- interest, not affinity
	local iRel = ReligionOf(p)
	return p:IsDoF(pLeader:GetID()) or (iRel >= 0 and iRel == ReligionOf(pLeader))
end

-- Candidates who would join if pLeader founded now (humans are invited instead and not counted).
function FN.OrgCandidates(o, pLeader)
	local t = { pLeader }
	for i = 0, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and i ~= pLeader:GetID() and FN.OrgEligible(o, p) and not (not p:IsMinorCiv() and p:IsHuman()) and FN.OrgWilling(o, p, pLeader) then
			table.insert(t, p)
		end
	end
	return t
end

function FN.CanFound(o, pLeader)
	if FN.OrgActive(o) then return false, "ACTIVE" end
	if pLeader:IsMinorCiv() or not FN.OrgEligible(o, pLeader) then return false, "INELIGIBLE" end
	if pLeader:GetCurrentEra() < o.MinEra then return false, "ERA" end
	if o.MaxEra and pLeader:GetCurrentEra() > o.MaxEra then return false, "OBSOLETE" end
	if #FN.OrgCandidates(o, pLeader) < o.MinMembers then return false, "MEMBERS" end
	return true
end

------------------------------------------------------------------------------
-- Membership changes
------------------------------------------------------------------------------
local function SetMember(o, p, bMember)
	local iP = p:GetID()
	FN.Set("OM_" .. o.Type .. "_" .. iP, bMember and 1 or 0)
	if not p:IsMinorCiv() then
		if o.PolicyID then p:SetHasPolicy(o.PolicyID, bMember, true) end
		if o.OpenBorders then
			for _, q in ipairs(FN.Members(o)) do
				if q:GetID() ~= iP and not q:IsMinorCiv() then
					Teams[p:GetTeam()]:SetOpenBorders(q:GetTeam(), bMember)
					Teams[q:GetTeam()]:SetOpenBorders(p:GetTeam(), bMember)
				end
			end
		end
	end
end

local function NotifyMembers(o, sText, sSummary)
	for _, p in ipairs(FN.Members(o)) do
		if not p:IsMinorCiv() then FN.Notify(p, sText, sSummary) end
	end
end

function FN.FoundOrg(o, pLeader)
	if not FN.CanFound(o, pLeader) then return false end
	FN.Set("OF_" .. o.Type, Game.GetGameTurn())
	FN.Set("OL_" .. o.Type, pLeader:GetID())
	local tJoined = {}
	for _, p in ipairs(FN.OrgCandidates(o, pLeader)) do
		SetMember(o, p, true)
		table.insert(tJoined, FN.PlayerName(p))
	end
	FN.NotifyKnown(pLeader, L("TXT_KEY_FN_NOTIFY_ORG_FOUNDED", FN.PlayerName(pLeader), o.Title, table.concat(tJoined, ", ")),
		L("TXT_KEY_FN_NOTIFY_ORG_FOUNDED_S", o.Title))
	FN.Log("%s founded by %d with %d members", o.Type, pLeader:GetID(), #tJoined)
	FN.InviteHumans(o)
	return true
end

function FN.JoinOrg(o, p)
	if not FN.OrgActive(o) or FN.IsMember(o, p:GetID()) or not FN.OrgEligible(o, p) then return false end
	SetMember(o, p, true)
	FN.Set("OI_" .. o.Type .. "_" .. p:GetID(), 0)
	NotifyMembers(o, L("TXT_KEY_FN_NOTIFY_ORG_JOINED", FN.PlayerName(p), o.Title), L("TXT_KEY_FN_NOTIFY_ORG_JOINED_S", o.Title))
	FN.Log("%d joined %s", p:GetID(), o.Type)
	return true
end

local function DissolveOrg(o, sReason)
	local tMembers = FN.Members(o)
	for _, p in ipairs(tMembers) do SetMember(o, p, false) end
	for _, p in ipairs(tMembers) do
		if not p:IsMinorCiv() then FN.Notify(p, L("TXT_KEY_FN_NOTIFY_ORG_DISSOLVED", o.Title), L("TXT_KEY_FN_NOTIFY_ORG_DISSOLVED_S", o.Title)) end
	end
	FN.Set("OF_" .. o.Type, 0)
	FN.Set("OL_" .. o.Type, 0)
	FN.Log("%s dissolved (%s)", o.Type, sReason)
end

function FN.LeaveOrg(o, p)
	if not FN.IsMember(o, p:GetID()) then return false end
	SetMember(o, p, false)
	NotifyMembers(o, L("TXT_KEY_FN_NOTIFY_ORG_LEFT", FN.PlayerName(p), o.Title), L("TXT_KEY_FN_NOTIFY_ORG_LEFT_S", o.Title))
	FN.Log("%d left %s", p:GetID(), o.Type)
	local tMembers = FN.Members(o)
	if #tMembers < 2 then
		DissolveOrg(o, "too few members")
	elseif FN.OrgLeader(o) == p:GetID() then
		-- Leadership passes to the next major member.
		for _, q in ipairs(tMembers) do
			if not q:IsMinorCiv() then FN.Set("OL_" .. o.Type, q:GetID()); break end
		end
	end
	return true
end

function FN.InviteHumans(o)
	local pLeader = Players[FN.OrgLeader(o)]
	if not pLeader then return end
	for i = 0, FN.MAX_MAJOR - 1 do
		local p = Players[i]
		if p and p:IsAlive() and p:IsHuman() and not FN.IsMember(o, i) and FN.OrgEligible(o, p)
			and FN.GetN("OI_" .. o.Type .. "_" .. i) == 0 and not Hostile(p, pLeader) then
			FN.Set("OI_" .. o.Type .. "_" .. i, Game.GetGameTurn())
			FN.Notify(p, L("TXT_KEY_FN_NOTIFY_ORG_INVITED", o.Title), L("TXT_KEY_FN_NOTIFY_ORG_INVITED_S", o.Title))
		end
	end
end

------------------------------------------------------------------------------
-- Turn processing
------------------------------------------------------------------------------
-- Effects and membership upkeep run once per turn, in the leading member's turn.
local function ProcessOrg(o)
	local pLeader = Players[FN.OrgLeader(o)]
	if o.MaxEra and pLeader:GetCurrentEra() > o.MaxEra then DissolveOrg(o, "obsolete"); return end

	-- Members who no longer qualify or turned hostile leave; willing candidates join.
	for _, p in ipairs(FN.Members(o)) do
		if p:GetID() ~= pLeader:GetID() then
			local bStay = FN.OrgEligible(o, p) and not Hostile(p, pLeader)
			if bStay and p:IsMinorCiv() then bStay = p:GetMinorCivFriendshipWithMajor(pLeader:GetID()) >= 0 end
			if not bStay then FN.LeaveOrg(o, p) end
		end
	end
	if not FN.OrgActive(o) then return end
	for i = 0, FN.MAX_CIV - 1 do
		local p = Players[i]
		if p and not FN.IsMember(o, i) and FN.OrgEligible(o, p) and not (not p:IsMinorCiv() and p:IsHuman()) and FN.OrgWilling(o, p, pLeader) then
			FN.JoinOrg(o, p)
		end
	end
	FN.InviteHumans(o)

	-- Effects for major members.
	local tMembers = FN.Members(o)
	local tIsMember = {}
	for _, p in ipairs(tMembers) do tIsMember[p:GetID()] = true end
	for _, p in ipairs(tMembers) do
		if not p:IsMinorCiv() then
			local iGold = 0
			if o.TradeRouteGold > 0 then
				for _, route in ipairs(p:GetTradeRoutes()) do
					if route.ToID ~= p:GetID() and tIsMember[route.ToID] then iGold = iGold + o.TradeRouteGold end
				end
			end
			if o.ResourceGold > 0 and o.ResourceID then
				iGold = iGold + math.min(10, p:GetNumResourceTotal(o.ResourceID, false)) * o.ResourceGold
			end
			if iGold > 0 then p:ChangeGold(iGold) end
			FN.Set("OG_" .. o.Type .. "_" .. p:GetID(), iGold)
			if o.MinorInfluence > 0 then
				for _, q in ipairs(tMembers) do
					if q:IsMinorCiv() then q:ChangeMinorCivFriendshipWithMajor(p:GetID(), o.MinorInfluence) end
				end
			end
			if o.OpenBorders then
				for _, q in ipairs(tMembers) do
					if q ~= p and not q:IsMinorCiv() then Teams[p:GetTeam()]:SetOpenBorders(q:GetTeam(), true) end
				end
			end
		end
	end
end

-- Called in every major's turn.
function FN.ProcessOrganisations(pPlayer)
	local iPlayer = pPlayer:GetID()
	for _, o in ipairs(FN.Orgs) do
		if FN.OrgActive(o) then
			local pLeader = Players[FN.OrgLeader(o)]
			if not pLeader or not pLeader:IsAlive() then
				local tMembers = FN.Members(o)
				local pNext = nil
				for _, q in ipairs(tMembers) do if not q:IsMinorCiv() then pNext = q; break end end
				if pNext then FN.Set("OL_" .. o.Type, pNext:GetID()) else DissolveOrg(o, "no major member") end
			elseif FN.OrgLeader(o) == iPlayer then
				ProcessOrg(o)
			end
		elseif not pPlayer:IsHuman() and FN.CanFound(o, pPlayer) then
			FN.FoundOrg(o, pPlayer)
		end
	end
end
