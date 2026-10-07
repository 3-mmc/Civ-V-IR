-- Formable Nations for Vox Populi: turn hooks, union outlines, panel. Design: CivVNeo/docs/formable-nations-design.md
-- Single-player only: actions from the panel change game state directly from UI Lua.
include("InstanceManager")
include("FLuaVector")
include("FN_Core")
include("FN_Cohesion")
include("FN_Organisations")
include("FN_Independence")

local L = FN.L
local OVERLAY_STYLES = { "FN_Union1", "FN_Union2", "FN_Union3", "FN_Union4", "FN_Union5", "FN_Union6", "FN_Union7", "FN_Union8" }

------------------------------------------------------------------------------
-- Turn processing
------------------------------------------------------------------------------
GameEvents.PlayerDoTurn.Add(function(iPlayer)
	if iPlayer < 0 or iPlayer >= FN.MAX_MAJOR then return end
	local pPlayer = Players[iPlayer]
	if not pPlayer or not pPlayer:IsAlive() then return end
	FN.ProcessCohesion(pPlayer)
	FN.ConsiderStages(pPlayer)
	FN.ProcessOrganisations(pPlayer)
	FN.ProcessProvinces(pPlayer)
end)
GameEvents.CityCaptureComplete.Add(FN.OnCityCaptured)

------------------------------------------------------------------------------
-- Union outlines: one outer outline around leader + bound partners, in the leader's secondary colour.
------------------------------------------------------------------------------
local g_bOverlay = (FN.GetN("OVERLAY_OFF") == 0)

function FN.DrawOverlay()
	for _, sStyle in ipairs(OVERLAY_STYLES) do Events.ClearHexHighlightStyle(sStyle) end
	if not g_bOverlay then return end
	local iActiveTeam = Game.GetActiveTeam()
	for iLeader = 0, FN.MAX_MAJOR - 1 do
		local pLeader = Players[iLeader]
		if pLeader and pLeader:IsAlive() then
			for _, s in ipairs(FN.Stages) do
				if s.IsUnion and FN.HasStage(pLeader, s) then
					local tMembers = { [iLeader] = true }
					for _, b in ipairs(FN.BondsOf(pLeader, s)) do tMembers[b.Partner:GetID()] = true end
					local _, secondary = pLeader:GetPlayerColors()
					local color = Vector4(secondary.x, secondary.y, secondary.z, 0.9)
					local sStyle = OVERLAY_STYLES[(iLeader % #OVERLAY_STYLES) + 1]
					for i = 0, Map.GetNumPlots() - 1 do
						local pPlot = Map.GetPlotByIndex(i)
						if tMembers[pPlot:GetOwner()] and pPlot:IsRevealed(iActiveTeam, false) then
							Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(pPlot:GetX(), pPlot:GetY())), true, color, sStyle)
						end
					end
				end
			end
		end
	end
end

Events.ActivePlayerTurnStart.Add(function() FN.DrawOverlay() end)
Events.LoadScreenClose.Add(function() FN.DrawOverlay() end)

------------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------------
local g_CardIM = InstanceManager:new("CardInstance", "Root", Controls.MainStack)
local g_sTab = "NATIONS"
local RefreshPanel

local function Mark(line)
	local sIndent = line.Indent and "    " or ""
	local sColor = line.Ok and "[COLOR_POSITIVE_TEXT]" or "[COLOR_NEGATIVE_TEXT]"
	return sIndent .. "[ICON_BULLET]" .. sColor .. line.Text .. "[ENDCOLOR]"
end

-- tButtons: list of { Text, Enabled, Call } (at most three).
local function AddCard(sHeader, sQuote, sBody, tButtons)
	local inst = g_CardIM:GetInstance()
	inst.Header:SetText(sHeader or "")
	inst.Header:SetHide(sHeader == nil)
	inst.Quote:SetText(sQuote or "")
	inst.Quote:SetHide(sQuote == nil)
	inst.Body:SetText(sBody or "")
	tButtons = tButtons or {}
	for i = 1, 3 do
		local btn, lbl, b = inst["Button" .. i], inst["Label" .. i], tButtons[i]
		btn:SetHide(b == nil)
		if b then
			lbl:SetText(b.Text)
			btn:SetDisabled(not b.Enabled)
			btn:RegisterCallback(Mouse.eLClick, function() if b.Call() ~= false then RefreshPanel() end end)
		end
	end
	inst.Buttons:SetHide(#tButtons == 0)
	inst.Buttons:CalculateSize()
	inst.Root:CalculateSize()
	inst.Root:ReprocessAnchoring()
end

local function EraName(iEra) return GameInfo.Eras[iEra].Description end

local function StatusText(pPlayer, s, r)
	if r.Formed then return L("TXT_KEY_FN_STATUS_FORMED", FN.GetN("T_" .. pPlayer:GetID() .. "_" .. s.Type)) end
	if r.Superseded then return L("TXT_KEY_FN_STATUS_SUPERSEDED") end
	if r.MissingGroup then return L("TXT_KEY_FN_STATUS_IMPOSSIBLE", r.MissingGroup) end
	if r.Expired then return L("TXT_KEY_FN_STATUS_EXPIRED", EraName(s.MaxEra)) end
	if r.Ready then return L("TXT_KEY_FN_STATUS_READY") end
	return L("TXT_KEY_FN_STATUS_WAITING")
end

local function ShowNations(pActive)
	local iCiv = pActive:GetCivilizationType()
	local bAny = false
	for _, s in ipairs(FN.Stages) do
		if s.CivID == iCiv then
			bAny = true
			local r = FN.EvaluateStage(pActive, s)
			local tBody = { StatusText(pActive, s, r) }
			if not r.Formed and not r.Superseded then
				for _, line in ipairs(r.Lines) do table.insert(tBody, Mark(line)) end
			end
			table.insert(tBody, L("TXT_KEY_FN_BONUS", s.Help))
			for _, u in ipairs(s.UniqueUnits) do
				table.insert(tBody, L("TXT_KEY_FN_PERK_UNIT", GameInfo.Units[u.Unit].Description, GameInfo.Units[u.Replaces].Description,
					GameInfo.Units[u.Unit].Help))
			end
			if s.GoldenAgeTurns > 0 then table.insert(tBody, L("TXT_KEY_FN_PERK_GOLDEN_AGE", s.GoldenAgeTurns)) end
			if s.Desc then table.insert(tBody, L("TXT_KEY_FN_RENAME", s.Desc)) end
			if s.IsUnion then table.insert(tBody, "[COLOR_GREY]" .. L("TXT_KEY_FN_UNION_NOTE") .. "[ENDCOLOR]") end
			local tButtons = {}
			if not (r.Formed or r.Superseded or not r.Possible) then
				tButtons[1] = { Text = L("TXT_KEY_FN_FORM_BUTTON"), Enabled = r.Ready and pActive:IsTurnActive(),
					Call = function() return FN.FormStage(pActive, s) end }
			end
			AddCard(L("TXT_KEY_FN_STAGE_HEADER", s.Title, L("TXT_KEY_FN_TIER_" .. s.Tier), EraName(s.MinEra), EraName(s.MaxEra)),
				s.Quote and L(s.Quote), table.concat(tBody, "[NEWLINE]"), tButtons)
		end
	end
	if not bAny then AddCard(nil, nil, L("TXT_KEY_FN_NONE_FOR_CIV")) end
end

local function CohesionBar(fC)
	local S = FN.S
	local sColor = (fC >= S.COHESION_INTEGRATED and "[COLOR_POSITIVE_TEXT]") or (fC < S.COHESION_CRISIS and "[COLOR_NEGATIVE_TEXT]") or "[COLOR_YELLOW]"
	return sColor .. string.format("%d", math.floor(fC)) .. "[ENDCOLOR]"
end

local function ShowUnions(pActive)
	local iL, bAny = pActive:GetID(), false
	for _, s in ipairs(FN.Stages) do
		if s.IsUnion and FN.HasStage(pActive, s) then
			for _, b in ipairs(FN.BondsOf(pActive, s)) do
				bAny = true
				local pPartner = b.Partner
				local iP = pPartner:GetID()
				local fC = FN.GetCohesion(iL, iP)
				local iE, tTerms = FN.Equilibrium(pActive, pPartner)
				local tBody = {
					L("TXT_KEY_FN_COHESION_LINE", CohesionBar(fC), iE,
						L(iE > fC + 0.5 and "TXT_KEY_FN_TREND_UP" or (iE < fC - 0.5 and "TXT_KEY_FN_TREND_DOWN" or "TXT_KEY_FN_TREND_FLAT"))),
				}
				for _, t in ipairs(tTerms) do
					table.insert(tBody, Mark({ Ok = t.Value > 0, Indent = true, Text = L("TXT_KEY_FN_TERM_" .. t.Key) .. string.format(" %+d", t.Value) }))
				end
				local iForecast = FN.SecessionForecast(iL, iP, iE)
				if iForecast then table.insert(tBody, L("TXT_KEY_FN_FORECAST", iForecast)) end
				local iSecede = FN.GetN("BSC_" .. iL .. "_" .. iP)
				if iSecede > 0 then table.insert(tBody, L("TXT_KEY_FN_SECEDING", iSecede - Game.GetGameTurn())) end

				local tButtons = nil
				if FN.InCrisis(iL, iP) then
					table.insert(tBody, L("TXT_KEY_FN_CRISIS_PROMPT", FN.ConcedeCost(pActive), FN.PrivilegeTribute(pActive), FN.S.ASSERT_INFLUENCE_COST))
					local bTurn = pActive:IsTurnActive()
					tButtons = {
						{ Text = L("TXT_KEY_FN_CRISIS_CONCEDE"), Enabled = bTurn and pActive:GetGold() >= FN.ConcedeCost(pActive),
							Call = function() return FN.RespondCrisis(pActive, pPartner, "CONCEDE") end },
						{ Text = L("TXT_KEY_FN_CRISIS_PRIVILEGE"), Enabled = bTurn, Call = function() return FN.RespondCrisis(pActive, pPartner, "PRIVILEGE") end },
						{ Text = L("TXT_KEY_FN_CRISIS_ASSERT"), Enabled = bTurn, Call = function() return FN.RespondCrisis(pActive, pPartner, "ASSERT") end },
					}
				end
				AddCard(L("TXT_KEY_FN_BOND_HEADER", FN.PlayerName(pPartner), s.Title), nil, table.concat(tBody, "[NEWLINE]"), tButtons)
			end
		end
	end
	if not bAny then AddCard(nil, nil, L("TXT_KEY_FN_NO_UNIONS")) end
end

local function ShowProvinces(pActive)
	local S = FN.S
	local tProvinces = FN.Provinces(pActive)
	AddCard(nil, nil, L("TXT_KEY_FN_PROVINCES_INTRO"))
	for _, prov in ipairs(tProvinces) do
		local pCity, sKind = prov.City, prov.Kind
		local fC = FN.CityCohesion(pCity)
		local iE, tTerms = FN.CityEquilibrium(pCity, sKind)
		local tBody = {
			L("TXT_KEY_FN_COHESION_LINE", CohesionBar(fC), iE,
				L(iE > fC + 0.5 and "TXT_KEY_FN_TREND_UP" or (iE < fC - 0.5 and "TXT_KEY_FN_TREND_DOWN" or "TXT_KEY_FN_TREND_FLAT"))),
		}
		for _, t in ipairs(tTerms) do
			table.insert(tBody, Mark({ Ok = t.Value > 0, Indent = true, Text = L("TXT_KEY_FN_TERM_" .. t.Key) .. string.format(" %+d", t.Value) }))
		end
		local iIntegrate = FN.IntegrationForecast(pCity)
		if iIntegrate then table.insert(tBody, L("TXT_KEY_FN_PROVINCE_INTEGRATING", iIntegrate)) end
		local iBreak = FN.BreakawayTurn(pCity)
		if iBreak > 0 then
			table.insert(tBody, L("TXT_KEY_FN_PROVINCE_BREAKING", math.max(0, iBreak - Game.GetGameTurn())))
		elseif fC < S.CITY_SECESSION and not FN.CanBreakAway(pActive, pCity, sKind) then
			table.insert(tBody, L("TXT_KEY_FN_PROVINCE_HELD"))
		end
		local tButtons = nil
		if FN.InMovement(pCity) then
			local bTurn = pActive:IsTurnActive()
			local iCost = FN.AutonomyCost(pActive)
			table.insert(tBody, L("TXT_KEY_FN_MOVEMENT_PROMPT", iCost, S.SUPPRESS_RESISTANCE))
			tButtons = {
				{ Text = L("TXT_KEY_FN_MOVEMENT_AUTONOMY"), Enabled = bTurn and pActive:GetGold() >= iCost,
					Call = function() return FN.RespondMovement(pActive, pCity, "AUTONOMY") end },
				{ Text = L("TXT_KEY_FN_MOVEMENT_SUPPRESS"), Enabled = bTurn and pCity:GetGarrisonedUnit() ~= nil,
					Call = function() return FN.RespondMovement(pActive, pCity, "SUPPRESS") end },
				{ Text = L("TXT_KEY_FN_MOVEMENT_RELEASE"), Enabled = bTurn and FN.BreakawayDestination(pActive, pCity, sKind) ~= nil,
					Call = function() return FN.RespondMovement(pActive, pCity, "RELEASE") end },
			}
		end
		AddCard(L("TXT_KEY_FN_PROVINCE_HEADER", pCity:GetName(), L("TXT_KEY_FN_KIND_" .. sKind)), nil, table.concat(tBody, "[NEWLINE]"), tButtons)
	end
	if #tProvinces == 0 then AddCard(nil, nil, L("TXT_KEY_FN_NO_PROVINCES")) end
end

local FOUND_REASON = { ACTIVE = "TXT_KEY_FN_ORG_WHY_ACTIVE", INELIGIBLE = "TXT_KEY_FN_ORG_WHY_INELIGIBLE", ERA = "TXT_KEY_FN_ORG_WHY_ERA",
	OBSOLETE = "TXT_KEY_FN_ORG_WHY_OBSOLETE", MEMBERS = "TXT_KEY_FN_ORG_WHY_MEMBERS" }

local function ShowOrganisations(pActive)
	local iActive = pActive:GetID()
	for _, o in ipairs(FN.Orgs) do
		local bEligible = FN.OrgEligible(o, pActive)
		local bActive = FN.OrgActive(o)
		if bEligible or bActive then
			local tBody = { L("TXT_KEY_FN_ORG_DEPTH_" .. o.Depth), L("TXT_KEY_FN_BONUS", o.Help) }
			local tButtons = {}
			local bTurn = pActive:IsTurnActive()
			if bActive then
				local tNames = {}
				for _, p in ipairs(FN.Members(o)) do table.insert(tNames, FN.PlayerName(p)) end
				table.insert(tBody, L("TXT_KEY_FN_ORG_MEMBERS", FN.PlayerName(Players[FN.OrgLeader(o)]), table.concat(tNames, ", ")))
				if FN.IsMember(o, iActive) then
					local iGold = FN.GetN("OG_" .. o.Type .. "_" .. iActive)
					if iGold > 0 then table.insert(tBody, L("TXT_KEY_FN_ORG_INCOME", iGold)) end
					tButtons[1] = { Text = L("TXT_KEY_FN_ORG_LEAVE"), Enabled = bTurn, Call = function() return FN.LeaveOrg(o, pActive) end }
				elseif bEligible then
					tButtons[1] = { Text = L("TXT_KEY_FN_ORG_JOIN"), Enabled = bTurn, Call = function() return FN.JoinOrg(o, pActive) end }
				end
			else
				local bCan, sWhy = FN.CanFound(o, pActive)
				local tCandidates = FN.OrgCandidates(o, pActive)
				table.insert(tBody, L("TXT_KEY_FN_ORG_CANDIDATES", #tCandidates, o.MinMembers))
				if not bCan then table.insert(tBody, Mark({ Ok = false, Text = L(FOUND_REASON[sWhy] or "TXT_KEY_FN_ORG_WHY_INELIGIBLE", EraName(o.MinEra)) })) end
				tButtons[1] = { Text = L("TXT_KEY_FN_ORG_FOUND"), Enabled = bCan and bTurn, Call = function() return FN.FoundOrg(o, pActive) end }
			end
			local sEras = o.MaxEra and L("TXT_KEY_FN_ORG_ERAS", EraName(o.MinEra), EraName(o.MaxEra)) or L("TXT_KEY_FN_ORG_FROM_ERA", EraName(o.MinEra))
			AddCard(L(o.Title) .. " [COLOR_GREY](" .. sEras .. ")[ENDCOLOR]", o.Quote and L(o.Quote), table.concat(tBody, "[NEWLINE]"), tButtons)
		end
	end
end

local function ShowWorld(pActive)
	local iActiveTeam, bAny = pActive:GetTeam(), false
	for i = 0, FN.MAX_MAJOR - 1 do
		local p = Players[i]
		if i ~= pActive:GetID() and p and p:IsAlive() and Teams[iActiveTeam]:IsHasMet(p:GetTeam()) then
			for _, s in ipairs(FN.Stages) do
				if FN.HasStage(p, s) then
					bAny = true
					AddCard(nil, nil, "[ICON_BULLET]" .. L("TXT_KEY_FN_WORLD_ENTRY", p:GetName(), s.Title, GameInfo.Civilizations[p:GetCivilizationType()].ShortDescription))
				end
			end
		end
	end
	for _, o in ipairs(FN.Orgs) do
		if FN.OrgActive(o) then
			bAny = true
			local tNames = {}
			for _, p in ipairs(FN.Members(o)) do table.insert(tNames, FN.PlayerName(p)) end
			AddCard(nil, nil, "[ICON_BULLET]" .. L("TXT_KEY_FN_WORLD_ORG", o.Title, table.concat(tNames, ", ")))
		end
	end
	if not bAny then AddCard(nil, nil, L("TXT_KEY_FN_WORLD_NONE")) end
end

RefreshPanel = function()
	g_CardIM:ResetInstances()
	local pActive = Players[Game.GetActivePlayer()]
	if g_sTab == "NATIONS" then ShowNations(pActive)
	elseif g_sTab == "UNIONS" then ShowUnions(pActive)
	elseif g_sTab == "ORGS" then ShowOrganisations(pActive)
	elseif g_sTab == "PROVINCES" then ShowProvinces(pActive)
	else ShowWorld(pActive) end
	-- The current tab shows as a disabled button.
	Controls.TabNations:SetDisabled(g_sTab == "NATIONS")
	Controls.TabUnions:SetDisabled(g_sTab == "UNIONS")
	Controls.TabOrgs:SetDisabled(g_sTab == "ORGS")
	Controls.TabProvinces:SetDisabled(g_sTab == "PROVINCES")
	Controls.TabWorld:SetDisabled(g_sTab == "WORLD")
	Controls.OverlayLabel:SetText(L(g_bOverlay and "TXT_KEY_FN_OVERLAY_ON" or "TXT_KEY_FN_OVERLAY_OFF"))
	Controls.MainStack:CalculateSize()
	Controls.MainStack:ReprocessAnchoring()
	Controls.ScrollPanel:CalculateInternalSize()
	Controls.ScrollPanel:SetScrollValue(0)
	FN.DrawOverlay()
end

local function SelectTab(sTab) return function() g_sTab = sTab; RefreshPanel() end end
function FN.ShowPanelTab(sTab) SelectTab(sTab)() end -- also used by tests/harness.lua
Controls.TabNations:RegisterCallback(Mouse.eLClick, SelectTab("NATIONS"))
Controls.TabUnions:RegisterCallback(Mouse.eLClick, SelectTab("UNIONS"))
Controls.TabOrgs:RegisterCallback(Mouse.eLClick, SelectTab("ORGS"))
Controls.TabProvinces:RegisterCallback(Mouse.eLClick, SelectTab("PROVINCES"))
Controls.TabWorld:RegisterCallback(Mouse.eLClick, SelectTab("WORLD"))

local function OpenPanel() RefreshPanel(); ContextPtr:SetHide(false) end
local function ClosePanel() ContextPtr:SetHide(true) end

Controls.CloseButton:RegisterCallback(Mouse.eLClick, ClosePanel)
Controls.OverlayButton:RegisterCallback(Mouse.eLClick, function()
	g_bOverlay = not g_bOverlay
	FN.Set("OVERLAY_OFF", g_bOverlay and 0 or 1)
	RefreshPanel()
end)

ContextPtr:SetInputHandler(function(uiMsg, wParam)
	if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE and not ContextPtr:IsHidden() then
		ClosePanel()
		return true
	end
end)

-- Entry in the EUI / base-game "additional information" menu.
LuaEvents.AdditionalInformationDropdownGatherEntries.Add(function(tEntries)
	table.insert(tEntries, { text = L("TXT_KEY_FN_PANEL_TITLE"), call = OpenPanel })
end)
LuaEvents.RequestRefreshAdditionalInformationDropdownEntries()

------------------------------------------------------------------------------
-- Load: names live in PreGame and are re-applied on every load in case the save did not keep them.
------------------------------------------------------------------------------
for i = 0, FN.MAX_MAJOR - 1 do
	local p = Players[i]
	if p and p:IsEverAlive() then FN.ApplyIdentity(p) end
end
FN.DrawOverlay()
FN.Log("loaded: %d stages, %d organisations, union alliance turns %d", #FN.Stages, #FN.Orgs, FN.UNION_TURNS)
