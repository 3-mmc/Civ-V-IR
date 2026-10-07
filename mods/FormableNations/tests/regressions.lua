-- Edge cases from the source/engine review. Run by harness.lua after its campaign scenarios.
return function(env)
	local Check, NewPlayer, NewCity, CIV, MINOR = env.Check, env.NewPlayer, env.NewCity, env.CIV, env.MINOR
	local function Major(id, civ, human)
		local p = NewPlayer(id, { civ = CIV(civ), human = human, era = 7, gold = 10000, ideology = 1 })
		p.cities[1] = NewCity(id, id * 2, 0)
		p.origCap = p.cities[1]
		return p
	end
	local function Minor(id, name)
		local p = NewPlayer(id, { minor = MINOR(name) })
		p.cities[1] = NewCity(id, id, 0)
		p.origCap = p.cities[1]
		return p
	end
	local function SeedOrg(o, leader, members)
		FN.Set("OF_" .. o.Type, 101)
		FN.Set("OL_" .. o.Type, leader:GetID())
		for _, p in ipairs(members) do Check(FN.JoinOrg(o, p), "seed eligible member " .. p:GetID()) end
	end

	print("Regression: union progression and absorption")
	env.Reset()
	local a = Major(0, "POLAND", true)
	a.era = 3
	local b = Minor(22, "VILNIUS")
	a:AcquireCity(b.cities[1], true)
	Check(FN.FormStage(a, FN.StageByType.FN_KREWO), "owned claims still permit a union")
	Check(not FN.EvaluateStage(a, FN.StageByType.FN_COMMONWEALTH).Ready, "owned claims do not bypass the prerequisite tenure")
	env.SetTurn(110)
	Check(FN.EvaluateStage(a, FN.StageByType.FN_COMMONWEALTH).Ready, "an owned union can deepen after its tenure instead of being stuck without bonds")
	env.Reset()
	a = Major(0, "AUSTRIA", true)
	b = Minor(22, "BUDAPEST")
	b.married[0] = true
	local met, _, annex = FN.EvaluateClaim(a, { MinorID = b.minor, Mode = "ABSORB" })
	Check(met and annex, "a married city-state is charged for and absorbed by an absorption claim")
	local c = Minor(23, "BRATISLAVA")
	c.married[0] = true
	a.era = 4
	Check(FN.FormStage(a, FN.StageByType.FN_HABSBURG), "Habsburg union formed with two partners")
	FN.Set("BC_0_22", 350); FN.Set("BC_0_23", 350)
	FN.ProcessCohesion(a)
	Check((FN.InCrisis(0, 22) and not FN.InCrisis(0, 23)) or (FN.InCrisis(0, 23) and not FN.InCrisis(0, 22)), "only one union crisis opens at a time")
	local crisis = FN.InCrisis(0, 22) and b or c
	FN.RespondCrisis(a, crisis, "CONCEDE")
	FN.ProcessCohesion(a)
	Check(not FN.InCrisis(0, 22) and not FN.InCrisis(0, 23), "a response cools down crises across the whole union")
	env.Reset()
	a = Major(0, "ENGLAND", true); b = Major(1, "CELTS", false)
	Teams[1].vassalOf = 0
	local claim
	for _, g in ipairs(FN.StageByType.FN_GREAT_BRITAIN.Groups) do
		for _, item in ipairs(g.Claims) do if item.CivID == CIV("CELTS") then claim = item end end
	end
	Check(not FN.EvaluateClaim(a, claim), "Great Britain cannot absorb a sovereign Celtic vassal")
	a:AcquireCity(b.cities[1], true)
	Check(FN.EvaluateClaim(a, claim), "owning the Celtic capital satisfies the state claim")
	env.Reset()
	a = Major(0, "GERMANY", true); a.era = 4
	b = Minor(22, "WITTENBERG"); b.ally, b.alliedTurns = 0, 20
	b:AddUnit({ type = GameInfoTypes.UNIT_LANCER, combat = true, experience = 21, promotions = { veteran = true }, damage = 15 })
	Check(FN.FormStage(a, FN.StageByType.FN_GERMAN_EMPIRE), "allied Saxony is peacefully absorbed")
	local inherited = a.units[1]
	Check(inherited and inherited.experience == 21 and inherited.damage == 15 and inherited.promotions.veteran,
		"absorbed military units retain experience, promotions and damage")

	print("Regression: membership, succession and border grants")
	env.Reset()
	a = Major(0, "FRANCE", true); b = Major(1, "NETHERLANDS", false); c = Major(2, "ROME", false)
	local d = Major(3, "GERMANY", false)
	local eu, eec = FN.OrgByType.ORG_EU, FN.OrgByType.ORG_EEC
	SeedOrg(eec, a, { a, b, c, d })
	Check(FN.FoundOrg(eu, a), "EU succeeds an eligible EEC")
	Check(Teams[0].openBorders[1] and Teams[1].openBorders[0], "successor borders survive predecessor dissolution immediately")
	FN.LeaveOrg(eu, b)
	FN.ProcessOrganisations(a)
	Check(not FN.IsMember(eu, 1), "a departing AI is not immediately recruited with reset cohesion")
	Check(not FN.JoinOrg(eu, b), "human/API join also respects departure cooldown")
	env.SetTurn(131)
	Teams[0].war[1], Teams[1].war[0] = true, true
	Check(not FN.JoinOrg(eu, b), "war with the leader blocks joining")
	Teams[0].war[1], Teams[1].war[0] = false, false
	Teams[2].war[1], Teams[1].war[2] = true, true
	Check(not FN.JoinOrg(eu, b), "war with a nonleader member also blocks joining")
	Teams[2].war[1], Teams[1].war[2] = false, false
	Check(FN.JoinOrg(eu, b), "a peaceful member can rejoin after the cooldown")
	env.Reset()
	a = Major(0, "ARABIA", true); b = Minor(22, "ORMUS"); c = Minor(23, "SIDON")
	local arab = FN.OrgByType.ORG_ARAB_LEAGUE
	SeedOrg(arab, a, { a, b, c })
	FN.LeaveOrg(arab, a)
	Check(not FN.OrgActive(arab), "organisation dissolves when its last major leaves, even with two minors remaining")
	env.Reset(); env.SetTurn(0)
	a = Major(0, "ARABIA", true); b = Major(1, "EGYPT", false); c = Major(2, "MOROCCO", false)
	a.cities[1].religion, b.cities[1].religion, c.cities[1].religion = 1, 1, 1
	Check(FN.FoundOrg(arab, a) and FN.OrgActive(arab), "founding on turn zero (advanced starts) persists as active")

	print("Regression: saved war queue and simultaneous calls")
	env.Reset()
	a = Major(0, "ENGLAND", true); b = Major(1, "NETHERLANDS", false)
	c = Major(2, "OTTOMAN", false); d = Major(3, "AZTEC", false)
	a.cities[1].religion, b.cities[1].religion = 1, 1
	c.ideology, d.ideology = 2, 2
	Check(FN.FoundPact(a, { Name = "Regression pact", Obligation = "DEFENCE", Scope = "GLOBAL", NoSeparatePeace = false,
		Burden = "NONE", Hegemonic = false, OpenBorders = true }), "custom defence pact formed")
	local pact = FN.OrgByType.ORG_PACT_1
	Teams[2]:DeclareWar(1, false, 2)
	Teams[3]:DeclareWar(1, false, 3)
	dofile("UI/FN_Alliances.lua") -- recreate module locals, as on save/load
	FN.ProcessAllianceWars()
	Check(FN.PendingCall(pact, 0) == 2, "a reload retains unprocessed declarations")
	FN.AnswerCall(pact, a, false)
	Check(FN.PendingCall(pact, 0) == 3, "the second call survives answering the first")
	Teams[1].war[3], Teams[3].war[1] = false, false
	local credit = FN.Credibility(pact, 0)
	Check(not FN.AnswerCall(pact, a, true) and not Teams[0].war[3], "answering an obsolete call cannot restart a settled war")
	Check(FN.Credibility(pact, 0) == credit, "cancelled obligations carry no refusal penalty")

	print("Regression: engine-style city invalidation during fragmentation")
	env.Reset()
	a = Major(0, "ENGLAND", true)
	Minor(22, "SIDON").alive = false -- slots used by the following fresh breakaway
	local slot = NewPlayer(23, { minor = MINOR("QUEBEC_CITY") }); slot.alive, slot.everAlive = false, false
	local first = NewCity(0, 40, 40, "Colony A")
	local second = NewCity(0, 42, 40, "Colony B")
	for _, city in ipairs({ first, second }) do
		city.area, city.connected, city.religion = 2, false, 2
		table.insert(a.cities, city)
		local pi = city:Plot():GetPlotIndex()
		FN.Set("CW_" .. pi, 1); FN.Set("CC_" .. pi, 100); FN.Set("CS_" .. pi, 100)
	end
	local acquire = env.Player.AcquireCity
	env.Player.AcquireCity = function(self, old, ...)
		acquire(self, old, ...)
		local fresh = {}
		for k, v in pairs(old) do fresh[k] = v end
		setmetatable(fresh, getmetatable(old))
		for i, city in ipairs(self.cities) do if city == old then self.cities[i] = fresh end end
		fresh.plot.GetPlotCity = function() return fresh end
		old.GetOwner = function() error("access to destroyed CvCity") end
	end
	local ok, err = pcall(FN.ProcessProvinces, a)
	env.Player.AcquireCity = acquire
	Check(ok, "fragmentation reacquires follower cities through plots: " .. tostring(err))
	Check(first.plot:GetPlotCity():GetOwner() == 23 and second.plot:GetPlotCity():GetOwner() == 23, "both breakaway cities transferred despite invalidated originals")
end
