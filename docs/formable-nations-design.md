# Formable Nations — design

Status (2026-10-07): v0.2 built: nations, union cohesion and secession, and functional and intergovernmental organisations. Built for Vox Populi 5.4.6 + EUI. Every build runs an offline harness: the real Lua modules against a mock of the game API, with scripted scenarios in `mods/FormableNations/tests/`. **Not yet verified in the real game.**

## Goal

Civilizations can reshape themselves into historically grounded states: unions, empires and, late in the game, international blocs. Formation should feel earned and read as real history. Balance comes from requirements, maintenance and modest bonuses, not big numerical rewards. City-states stand in for the peoples Civ V has no civilization for: Lithuania, Hungary, Bohemia, Saxony, and so on.

## Three tiers

| Tier | Example | What it is | Partner's status | Era band |
|---|---|---|---|---|
| **I. Union** | Union of Krewo; Habsburg Monarchy; Holy Roman Empire | Dynastic or personal union. Partners stay separate players. | Allied city-states locked into the alliance; vassal major civs | Classical – Renaissance |
| **II. State** | Polish–Lithuanian Commonwealth; Austria-Hungary; German Empire; Great Britain | Real union or unification. The civ is renamed and partners are absorbed. | City-states absorbed peacefully, or already conquered | Renaissance – Modern |
| **III. Bloc** | European Union, ASEAN, African Union, Arab League | Supranational organisation of several sovereign members | Majors and city-states join as members; nobody is absorbed | Atomic – Information |

The same people can produce different outcomes in different eras, because each stage has an era window:

- **Germany**: Holy Roman Empire (Medieval–Renaissance; an elective union of estates crowned by the Pope), *or* the German Empire (Industrial–Modern; unification under Prussia). The HRE is not a prerequisite for 1871, so either route can happen.
- **Austria**: Habsburg Monarchy (Renaissance–Industrial; the 1526 personal union with Hungary) can become **Austria-Hungary** (Industrial–Modern; the 1867 Dual Monarchy).
- **Poland**: Union of Krewo (Medieval–Renaissance; the 1385 personal union) is *required* before the **Polish–Lithuanian Commonwealth** (Renaissance–Industrial; the 1569 Union of Lublin). The Commonwealth did not come from conquest.

Missing an era window is a real outcome. A Poland that reaches the Industrial era without the Commonwealth stays Poland.

## Claims

A stage lists *claim groups*. Each group names candidate cities and how many of them are needed. A claim points at a city-state's original capital or a major civ's original capital, and has a mode:

| Mode | Satisfied by | On formation | Maintained? |
|---|---|---|---|
| `UNION` | City-state allied with you for at least *N* turns (or married, for Austria); a major civ whose team is your vassal; or you own the city | City-state is bound into the union: its Influence with you is topped up each turn so ordinary decay can't end it | Yes. If a rival out-influences you, or war breaks out, the union dissolves |
| `ALLY` | City-state is currently your ally, or you own the city | Nothing. This is recognition, e.g. papal coronation | No |
| `ABSORB` | Same as `UNION` for city-states; owning the city for majors | City-state's cities and military units pass to you as a peaceful buyout (`AcquireCity(city, false, true)`, the engine's own city-state buyout path) at VP's buyout price | — |
| `OWN` | You own the city | Nothing | No |

*N* = 15 turns at Standard speed, scaled by game speed.

City-states are picked at random when a game is created, from a pool of about 110 (VP re-adds Brave New World's dropped city-states and adds about 45 more). VP's `MajorBlocksMinor` table keeps a civ's "homeland" city-state out while that civ is in play: Edinburgh, Dublin and Abernethy while the Celts are present; Stockholm, Helsinki and Sigtuna while Sweden is; Vienna and Enns while Austria is. **So a claim group names a people, with alternatives**: Scotland is Edinburgh the city-state, or the Celtic capital. Because of the block rule, exactly one of the two exists in any game. Where no such pair exists, a stage whose group can't be met is shown as **"not possible in this world"**. Other alternatives are written in where history supports them; for example, Hungary can be Budapest *or* Bratislava, which was Pressburg, the Hungarian coronation city from 1563 to 1830.

## General rules

- Formation is a deliberate act from the Formable Nations panel, opened from EUI's additional-information menu. AI players form a stage on their own as soon as they qualify and can pay.
- Each formation: you can't be in empire-wide unhappiness, and you can't be at war with any claimed city-state.
- **One identity at a time.** A later stage in a chain supersedes the earlier one: its bonus replaces the earlier bonus and its name replaces the earlier name. If a Tier I union dissolves, the bonus is lost and the name reverts.
- `PrereqStage` with `PrereqTurns`: for example, the Commonwealth needs the Krewo union to have held for 10 turns.
- Every player who has met the forming civ gets a notification.

## Rewards and balance

- **Identity**: the civ's name, short name and adjective change mid-game via `PreGame.SetCivilization*`. These are text keys, so the change shows correctly in every language and in every place the game names civs.
- **Bonus**: a hidden VP dummy policy (`PolicyBranchType` NULL, so VP marks it `IsDummy`). It doesn't count toward policy costs and doesn't show in the policy tree. Target strength: **half to one social policy**, themed to the history. Tier I bonuses are smaller because the binding itself (a locked ally) is already the main payoff.
- **Absorption** costs gold at VP's own city-state buyout formula and requires a long alliance. It's the only way for most civs to annex a city-state peacefully in VP, so it's capped at the claimed cities of a single stage.
- No warmonger penalty for peaceful unions. A diplomatic reaction from other civs protecting the city-state is wanted, but there's no Lua API for diplomacy modifiers; it would need DLL work in CivVNeo.

## Map overlay (union outline)

Each civ keeps its own border colours. A **second, outer outline** traces the combined territory of the union leader and its partners, in the leader's *secondary* colour (Poland's white, for example). It's drawn as a highlight-style `SplineBorder` over the set of all union-owned plots. That set is treated as one group, so the line follows only the outer perimeter, wrapping both states' borders.

- Each union draws in its own style slot (`FN_Union1`–`FN_Union8`, chosen by the leader's player number), so neighbouring unions don't merge into a single outline.
- Only plots the viewer has revealed are drawn, so the overlay doesn't leak hidden map.
- It refreshes at turn start and after any formation or dissolution, and can be switched on or off from the panel.
- Styles live in `Highlights.xml`, and the game loads only one. VP's VPUI already ships one, so the build script generates ours as **VP's file plus our styles**. When VP updates, the mod must be rebuilt.
- Not yet known: how far the outline sits from the native border. It needs visual tuning in-game (width, texture, alpha).

## Cohesion and secession (built, v0.2)

Every bond that is **not** an absorption has a cohesion score from 0 to 100. Bonds are union partners, vassal members of a union, players in a shared union, and bloc members. Absorbed cities have no cohesion: once a partner is integrated, VP's own city unrest and rebellion rules apply instead.

**Drift, not dice.** Each turn, cohesion moves about 2 points (Standard speed) toward an *equilibrium* value computed from the current situation. Trends are slow and visible; there are no random collapses.

| Pushes equilibrium up | Pushes it down |
|---|---|
| Your Influence lead over the next-strongest rival | A rival's Influence closing in, or coups and rigged elections against you |
| Shared majority religion in the partner's cities | You at war, especially when the partner's territory or units suffer |
| A trade route between you and the partner | Empire-wide unhappiness |
| Bordering territory | For major civs: harsh VP vassal treatment, high vassal taxes, a partner much stronger than you |
| Long tenure (small bonus) | Ideology mismatch (late game, majors only) |

**Thresholds.**
- **75+, Integrated.** The only way to deepen to the State stage. It replaces the flat "held for N turns" rule: you need cohesion ≥ 75 for N turns. This is the Lublin path: decades of shared rule *made* the merger.
- **40–75, Stable.** Nothing happens.
- **20–40, Autonomy crisis.** An event with choices. **Concede**: pay Gold or Influence for an equilibrium bonus over 20 turns. **Grant privileges**: give up part of the union bonus, which the partner then receives. **Assert control**: costs Influence with every *other* city-state, which see it as a warning.
- **Below 20, Secession countdown.** 5 turns, announced to every player, unless cohesion rises above 20 again. Then the union dissolves. A city-state goes free with its Influence reset to neutral; a vassal ends its vassalage.

**The partner has agency too.** An AI partner (or a human in multiplayer, below) can **petition for autonomy**: deliberately pull equilibrium down to win concessions. Or it can **pledge loyalty**: speed up integration in return for a share of the union bonus.

### Keeping unions from becoming too hard

- **A reasonably kept union sits at an equilibrium of 60–70 with no upkeep.** Crises come from rivals, wars and neglect, not from the passage of time.
- **Secession needs low cohesion *and* an active cause.** If no rival, war or unhappiness term is negative, cohesion stops falling at 40.
- At most one crisis per union at a time, followed by a 30-turn cooldown.
- At 2 points per turn, falling from 60 to 20 takes about 20 turns, so the panel's trend arrow and forecast ("secession risk in ~12 turns") give plenty of warning.
- **The flat Influence top-up from v0.1 is gone.** Instead, a bound city-state's Influence *resting point* with its leader is raised to the alliance threshold + 10 (`ChangeRestingPointChange`), so Influence settles there naturally. When the bond ends, the change is reverted.
- **What the harness shows:** three wars, unhappiness and a religious split together leave a union with a strong Influence lead at about 40, so it never reaches a crisis. A rival winning the partner over is decisive: a crisis follows, and after about 29 turns, secession, even with a concession. That matches the intent: rivals break unions, neglect alone doesn't.
- Deepening uses cohesion: Commonwealth, Austria-Hungary and Great Britain need every partner of their union at 75+ for 10 turns. The German Empire has no union predecessor and uses the alliance path.
- All tuning lives in the `FormableNation_Settings` table.
- Every value goes to `Lua.log` each turn. Tuning comes from AI autoplay runs, as the CivVNeo blueprint requires, not from guesswork.

## Unions between players (planned; multiplayer needs network work)

Two major civs, human or AI, can form a **dynastic union** with a senior and a junior partner, or an **equal union** with co-rulers. Both must accept.

- **Shared:** open borders, a defensive pact, shared map visibility, and the union bonus split between them. Union-level decisions need both: deepening, joint war, admitting a third member.
- **The junior's lever, an autonomy movement.** The junior invests Culture or Gold into autonomy points over many turns. It can attempt secession once autonomy exceeds the senior's *hold*: cohesion plus relative strength, times tenure. Success means independence with a short truce. Failure means a cohesion penalty and a cooldown.
- **The senior's levers:** concessions, investment in integration, or asserting control.
- **Both meters are visible to both players.** Betrayal is possible but telegraphed and costly, which is the intended strategic tension. Cooperation pays more: only a union that holds can deepen.
- **Technical gate:** multiplayer requires every state change to travel as a synchronised network message. Lua has no generic one: the stock `Network.Send*` calls are all fixed-purpose. Options are VP's custom unit missions (synchronised, but they need a unit selected), or a small CivVNeo DLL addition that adds a generic synchronised mod message. The DLL route is cleaner and comes with building our own DLL anyway.

## International organisations, by depth (Tier III; functional and intergovernmental built in v0.2, supranational in v0.4)

Three depths, mirroring union → state at international scale. All of them use the same membership and cohesion machinery.

| Depth | Commitment | Examples | Game hook |
|---|---|---|---|
| **Functional** | One game system; join and leave freely | Hanseatic League (Medieval–Renaissance, trade); Delian League (Classical, defence with tribute); Lombard League (Medieval, Italian city-states against an emperor); Zollverein (Industrial, customs union); OPEC (Atomic+, oil); a science consortium (CERN-like) | Trade-route yields between members; shared defence; **OPEC: members' Oil counts jointly toward VP's resource monopoly bonuses**, plus an output quota that trades Oil for Gold |
| **Intergovernmental** | Multi-purpose, consensual, sovereign | Arab League, African Union, ASEAN, Nordic Council, Mercosur | Open borders, World Congress votes as a bloc when unanimous, diplomatic opinion bonus between members, small trade bonus |
| **Supranational** | Deep integration with shared rules | European Union, evolving ECSC → EEC → EU | Single market (stronger trade yields), a cohesion budget (members pay a share of Gold, which flows to poorer members), a common World Congress vote, no war between members. Leaving takes an *N*-turn notice period, ends the benefits, and is followed by a trade penalty |

- **Membership criteria** come per organisation from data. Culture and region use civilization and city-state lists (ASEAN: Siam, Indonesia + Hanoi, Manila, Kuala Lumpur, Singapore, Malacca). Function uses game state (OPEC: owns Oil; Hanseatic: coastal cities with trade routes to members).
- **Functional organisations give the early and mid game an "international" layer**, and some feed national formation. Example: **German Empire via the Zollverein**, where sustained cohesion with the German city-states replaces annexation by force.
- **OPEC-style cartels** work as written. GCC-scale regional bodies are thin, because only one Gulf city-state exists (Ormus).
- **As built (v0.2):** the Hanseatic League and OPEC (functional), plus the Arab League, African Union, ASEAN, Nordic Council and Mercosur (intergovernmental). Effects are applied each turn in the lead member's turn: Gold per trade route between members, Gold per Oil (OPEC, capped at 10), Influence with member city-states, and real open borders via `Team:SetOpenBorders`.
- **Who joins:** city-states join when they're Friends with the leader. AI majors join functional organisations unless hostile (at war or denouncing); intergovernmental ones need a Declaration of Friendship or a shared majority religion. Humans are invited and accept in the panel. Members leave when they stop qualifying or turn hostile. The Hanseatic League dissolves after the Renaissance.
- **Known simplification:** leaving an organisation removes the open borders it granted, even if the same two civs also signed an open-borders deal. Separate tracking needs DLL work.
- **Supranational, as built (v0.4): the European chain.**
  - **Coal and Steel Community** (functional, Modern era). European nations owning Coal can join. It pays Gold per Coal and +3% Production.
  - **Economic Community** (intergovernmental, Atomic era). It can only be founded by a Coal and Steel Community member. It gives open borders, +3 Gold per trade route between members and +5% Gold.
  - **European Union** (supranational, Information era). It can only be founded by an Economic Community member. It gives open borders, +4 Gold per trade route between members, +5% Gold, +5% Science, +1 World Congress delegate and +2 Influence a turn with member City-States.
  - **Growing out of a predecessor:** `PrereqOrg` means a new organisation can only be founded by a member of its predecessor. Founding it merges the predecessor in for good (`OSUP_` save key), and the predecessor's members come along.
  - **No war between members:** handled through VP's `GameEvents.PlayerCanDeclareWar`. The mod switches on `EVENTS_WAR_AND_PEACE` in `CustomModOptions`, which is off by default.
  - **Member cohesion:** each major member has a cohesion score with the Union. It is raised by being the leading member (+5), sharing the leader's ideology (+10), trade with members (+8), a Declaration of Friendship with a member (+5) and years of membership. It is lowered by a rival ideology (-15), denunciations between members (-10) and unhappiness (-10). Below 25 an **exit referendum** is called and decided after 5 turns. Negotiated **opt-outs** (40 Gold x (era + 1)) call it off and add +15 for 20 turns; an AI negotiates them if it can afford twice the price. A member that votes to leave loses the benefits and may declare war again.
  - **Not yet built:** the cohesion budget (transfers to poorer members) and a common World Congress vote.

## Formation-only City-States (built, v0.6)

Some civs had no formation because the City-States their history needs don't exist. The mod adds 24 City-States, all with `Playable = 0`:
- They are never drawn at random, so the normal pool and trait ratios are untouched.
- They are never handed out to a random breakaway; a city literally named "Austin" may still become Austin.
- They appear only when the historical City-State setup swaps one in for a civ in the game that needs it.

Their colours and art styles follow VP's own homeland City-States (`PLAYERCOLOR_MINOR_<civ>`). Each needs a first-contact clip. The game reads these from VP's `MinorCivSounds_VoxPopuli.xml` in the game folder, which VP's `Expansion2.Civ5Pkg` loads, so `build.py --install` writes the mod's entries there between markers (`FormableNation_CityStateSounds`; original in `backups/vp/`). Like VP's own changes, a Steam "verify" or a VP reinstall resets it, so install again afterwards.

| Civ | City-States | Formation |
|---|---|---|
| Aztec | Texcoco, Tlacopan | Aztec Triple Alliance (I, Medieval–Renaissance): `UNION` both |
| Inca | Chan Chan, Quito | Tawantinsuyu (II, Medieval–Renaissance): `ABSORB` both |
| Maya | Chichen Itza, Uxmal | League of Mayapan (I, Classical–Medieval): `UNION` both |
| Korea | Gyeongju, Jeonju | Goryeo (II, Classical–Medieval): `ABSORB` both |
| Japan | Kagoshima, Hagi | Satcho Alliance (I, Renaissance–Industrial: `UNION` both) → Empire of Japan (II, Industrial–Modern: partners integrated 10 turns, then `ABSORB`) |
| Polynesia | Lahaina, Waimea | Kingdom of Hawaii (II, Renaissance–Industrial): `ABSORB` both |
| India | Gwalior, Baroda, Indore | Maratha Confederacy (I, Renaissance–Industrial): `UNION` 2 of 3 |
| Ethiopia | Lalibela, Harar | Solomonic Restoration (II, Medieval–Renaissance: `ABSORB` Lalibela); Ethiopian Empire (II, Industrial–Modern: `ABSORB` Harar) |
| Songhai | Timbuktu | Askia Dynasty (II, Medieval–Renaissance): `ABSORB` Timbuktu |
| Celts | Aberffraw, Quimper | Alliance of the Celtic Nations (I, Medieval–Renaissance): `UNION` both |
| Greece | Corinth, Megara | League of Corinth (I, Classical): `UNION` 2 of Corinth, Megara, Argos |
| America | Austin | Annexation of Texas (II, Industrial): `ABSORB` Austin |
| Egypt | Napata | New Kingdom (II, Ancient–Classical): `ABSORB` Napata |

**Japan.** The Empire of Japan is reached through its own unification: the Satsuma–Choshu alliance (1866), then the Meiji state, which abolished the domains in 1871. The alternative, via Taiwan and the Korean City-States, was considered and set aside: it would reward Japan's colonial annexations (Taiwan 1895, Korea 1910) as a formation, and the content rules exclude formations built on the conquest of a living people. For the same reason, Korea's City-States are claimed only by Goryeo.

**Still without a formation:** the Huns, Shoshone and Zulu (undecided).

## Alliances and defence pacts (built, v0.5)

The game's own defensive pact is a binary switch with no terms. Alliances here are organisations of Depth `ALLIANCE`, each with a written **charter**:

| Term | Options |
|---|---|
| Obligation | `DEFENCE`: an attack on one member is an attack on all · `FULL`: also members' own wars · `CONSULT`: a call to arms that may be refused without penalty |
| Scope | `GLOBAL` · `REGIONAL`: only aggressors whose capital lies within `ALLIANCE_REGION_TILES` (30) of the attacked member's (like NATO's Article 6) |
| Separate peace | allowed · forbidden while the member whose war it is still fights (`GameEvents.PlayerCanMakePeace` blocks peace treaties) |
| Burden | none · `TARGET`: military might at least 50% of the members' average (like NATO's 2%) · `TRIBUTE`: members pay the leader each turn (the Delian League) |
| Leadership | equals · leading power: the leader's own wars call members in, and members leave only by referendum (the Warsaw Pact) |
| Borders | open between members, or unchanged |

Members can never declare war on each other.

**Calls to arms.**
- **Queue:** `GameEvents.DeclareWar` fires inside the engine's declaration, before the war state is set. The mod therefore queues the declaration and resolves obligations in the next player's turn processing.
- **AI members:** an AI answers if its cohesion with the alliance is at least 40, and joins as a defensive-pact war (`Team:DeclareWar(team, true, player)`).
- **Human members:** you get a call on the Organisations tab and have 5 turns to honour or decline it; silence counts as refusal.
- **City-State members:** they always answer binding calls.
- **Credibility:** honouring a binding call gives +10 credibility and refusing gives -15. Credibility fades by 1 a turn, and enters cohesion as a term between -20 and +10.

**Cohesion.** Alliances reuse the supranational cohesion system: ideology, friendships, denunciations, unhappiness, tenure and exit referendums. They add three terms:
- credibility;
- a common **threat**: +10 when a stronger outside power's capital lies within 25 tiles;
- **burden**: the defence target met (+5) or missed (-10), or tribute paid (-5).

AI civs join an alliance on a Declaration of Friendship, a shared ideology or faith, or a common threat. City-States join if they're Friends.

**Historical alliances:**
- **Delian League:** Classical; defence, regional, tribute, leading power.
- **Lombard League:** Medieval; defence, regional, no separate peace.
- **Holy League:** Renaissance; full alliance.
- **Triple Alliance:** Industrial–Modern; defence.
- **Triple Entente:** Industrial–Modern; consultation only, since Britain's obligations to France were never written down.
- **NATO:** Atomic+; defence, regional, defence target.
- **Warsaw Pact:** Atomic+; defence, regional, no separate peace, leading power.
- **Covenant Chain:** Renaissance–Industrial; the Haudenosaunee and the English colonies.

**Player-drafted pacts.** There are three slots (`ORG_PACT_1..3`, from the Medieval era). The Organisations tab opens a charter window with a name field and one button per term. The name and terms are stored in save data (`PN_`, `PT_` keys). Because the mod controls everywhere the name is shown, a typed name works without engine text; markup characters are stripped.

## City-state pool and civ : city-state ratios

- **Facts.** The number of city-states comes from map size or setup. VP's selection keeps the ratio between city-state trait types. `MajorBlocksMinor` removes homeland city-states while their civ plays.
- **No duplicate Edinburghs.** The Edinburgh city-state is blocked whenever the Celts (whose capital is Edinburgh) are in the game. Automatically chosen city names are unique game-wide, including names of razed cities (`isCityNameValid` with destroyed-name checks). Only a manual rename by a human can duplicate a name, and that's cosmetic, since claims track original capitals, not names. Mid-game spawns (below) apply the same block and name check.
- **Weighted selection (DLL, planned).** City-states that appear in claims for civs actually in the game get extra weight inside VP's trait-ratio logic. Count and ratios stay the same; formations become possible more often. Setup option: Historical city-states — off / low / high.
- **Peoples, not cities, in claim data.** Use homeland pairs wherever VP provides them (Scotland: Edinburgh or the Celtic capital).
- **Absorption budget.** At most about 25% of the starting city-states can be absorbed peacefully per game; past that, unions stay unions. Independence (below) works the other way and creates city-states, so over a long game the two effects balance.

## Historical City-States at game start (built, v0.4)

City-States are drawn at random from about 120, so a formation's partners are often missing: Vilnius is in roughly one game in seven. Partners also often start far from the civ that would claim them ("map spaghetti"). `UI/FN_Setup.lua` fixes both without DLL or map-script work:

- **When:** once per game, as soon as every City-State has founded its city (at most `HISTORICAL_WAIT_TURNS` = 3 turns in), before most first contacts.
- **What is missing:** for every civ in the game and every claim group of its formations, City-States are added from the claim list (in listed order) until the group has as many present options as it needs. Blocked types (`MajorBlocksMinor`) and types already in play are skipped, so Edinburgh only comes in when the Celts are absent.
- **Which City-State makes way:** the one whose city is nearest the claiming civ's capital or starting plot, with a bonus for the same trait (`HISTORICAL_TRAIT_PREFERENCE` tiles). A City-State that any in-game formation refers to is never replaced. At most `HISTORICAL_MAX_PERCENT` = 50% of the City-States are replaced, and their number stays the same.
- **How:** VP's own path for replacing a City-State at game start. `Game.ChangeMinorPlayer` sets a never-used slot's type, and `Game.DoSpawnFreeCity(city)` (not "major founding") hands it the donor's city "as if founded there" and retires the donor, whose units die with it. The mod renames the city to the new City-State's name, removes the starting Settler the engine hands out, and re-creates the donor's military units for the newcomer.
- `HISTORICAL_CITY_STATES = 0` turns it off. A map-script approach (`AssignStartingPlots.lua` override) would place partners even more precisely, but it needs a generated copy of VP's script on every VP update. This is not planned unless the swap proves too coarse.

## Independence and fragmentation (built, v0.3)

**Engine basis.** VP already creates free City-States mid-game. `Game.DoSpawnFreeCity(city, true)` (`CreateFreeCityPlayer` with "major founding") brings a City-State slot to life with the city as its original capital, plus defenders. The engine first revives a dead City-State that once held the city; otherwise it opens the first never-used slot, whose type the mod sets beforehand with `Game.ChangeMinorPlayer`. If the slot does not take the type, the mod keeps the slot's own type only if it is unused, and otherwise skips the breakaway, so the same City-State never exists twice. Dead civilizations come back through `AcquireCity`, as in VP's own liberation, and `verifyAlive` revives them.

**Which cities can break away** (`FN.CityKind`):
- **Never:** the capital; cities on the capital's landmass (or within 12 tiles of it); City-States joined peacefully (buyout, marriage, formation); and any city that has **integrated**.
- **Colony:** founded by its owner on another landmass, at least 12 tiles from the capital.
- **Another people:** taken by conquest (recorded on `CityCaptureComplete`), or originally founded by another major civilization (for example, ceded in a treaty).

**Local cohesion** uses the union machinery per city, drifting 1 point a turn toward an equilibrium of 50 plus these terms:

| Term | Value |
|---|---|
| Connected to the capital / not connected | +5 / -5 |
| City's majority religion same as / different from the owner's | +10 / -10 |
| Garrison; puppet (self-governing) | +5 each |
| Years under your rule | +1 per 10 turns, up to +15 |
| Distance beyond 12 tiles | -1 per 5 tiles, up to -10 |
| Another people: original nation alive / dead / a City-State | -10 / -5 / -5 |
| Age of nationalism | -5 per era from the Industrial era, up to -15 |
| Empire unhappy / very unhappy / super unhappy | -10 / -15 / -20 |
| Public opinion: civil resistance / revolutionary wave | -10 / -20 |
| Autonomy granted / movement suppressed (temporary) | +15 / +20 |

As with unions, with no negative term active the equilibrium stays at 40 or more.

**Stages.**
- **Integration:** a city held at **75+** for **30 turns** integrates for good.
- **Movement:** below **35**, an independence movement forms. You can answer it on the **Provinces** tab:
  - **Grant autonomy:** costs 30 gold x (era + 1) and gives +15 for 20 turns.
  - **Suppress:** needs a garrison, gives +20 for 10 turns, and puts the city in resistance for 3 turns.
  - **Grant independence:** the city leaves in peace, and as a City-State it starts with +50 Influence toward you.

  An AI ruler grants autonomy if it can afford it twice over; otherwise it suppresses if it has a garrison.
- **Breakaway:** below **20**, there is a visible 8-turn countdown, cancelled if cohesion recovers.

**Where the city goes** (`FN.BreakawayDestination`):
1. **National revival:** another people's city whose original civilization is dead brings it back, with 2 defenders (Poland in 1918).
2. **Return:** if that civilization is alive and not at war with the owner, the city returns to it.
3. **Free City-State:** first, a City-State named like the city, if one is unused and not blocked (a seceding "Dublin" becomes Dublin). Next, for colonies, a colonial-era type (`FormableNation_ColonialStates`: Quebec City, Vancouver, Sydney, Melbourne, Wellington, Cape Town, Buenos Aires, Bogota, Panama City, Rio de Janeiro, Hong Kong, Singapore, Manila, Malacca, Colombo, Kuala Lumpur, Zanzibar, Mombasa, Valletta, Jakarta). Otherwise, any unused type. The city keeps its own name (`RENAME_BREAKAWAY = 0`, chosen 2026-10-07; 1 renames it to the City-State type). The City-State itself is still labelled with its type's name in diplomacy, because minor-civ names come only from `MinorCivilizations` (no Lua override); a true per-player name needs the CivVNeo DLL. A secession leaves the new City-State at -30 Influence toward its former ruler.

**Fragmentation.** Up to 2 other restless cities (same kind, movement under way) go with the breakaway: nearby cities on the same landmass (within 6 tiles) for a free City-State, or cities of the same original nation for a revival or return.

**Safeguards.** Cities of another people can break away from the Medieval era on, and colonies from the Industrial era on (`FormableNation_EraSettings`, stored by era type, so era mods do not shift them). There is at most one breakaway per player every 20 turns. The countdown waits while a breakaway is not allowed yet. The same rules apply to AI and human players.

**Limit:** civ slots are fixed when a game is created, so a new major civ cannot appear mid-game. There are about 17 spare City-State slots on a standard map.

## Perks of formed nations (built, v0.3)

Each formed nation has three kinds of perk:
- **Identity:** the civ's new name.
- **Economic perks:** a hidden dummy policy.
- **States (Tier II), and the Holy Roman Empire:** a **unique unit**, plus a **golden age on proclamation** for Tier II.

**Unique units** follow VP's own pattern for the B-17 and T-34. Each has its own unit class, `Units.PolicyType` gated by the stage's dummy policy, and `Policy_UnitClassReplacements`, so it replaces the generic unit for that player only. A civ's own unique unit for the same class is kept, and existing generic units upgrade into it. Each unit is a copy of its base unit as VP leaves it (stats, art, AI types, upgrades, flavours), plus a combat bonus and one free promotion. When a stage is superseded or dissolved, the policy goes, and new units of that kind can no longer be built.

| Nation | Unique unit (replaces) | Unit perk | Economic perks (added in v0.3) |
|---|---|---|---|
| Holy Roman Empire | Imperial Knight (Knight) | +2 Strength, Charge | - |
| Polish-Lithuanian Commonwealth | Haiduk (Musketman, a ranged unit in VP) | +2 Ranged Strength, Cover I | Wheat +1 Food +1 Gold ("granary of Europe") |
| Habsburg Monarchy | - | - | +25% Influence from Gold gifts ("Tu felix Austria nube") |
| Austria-Hungary | Kaiserschuetze (Great War Infantry) | +3, Drill I | Opera Houses +2 Culture |
| German Empire | Uhlan (Lancer; VP's Cavalry is a ranged skirmisher) | +2, Sentry | +15% internal trade route yields (Zollverein) |
| Kingdom of Great Britain | Highland Regiment (Rifleman) | +2, Charge | Harbors +1 Gold |

Tier II proclamations also start an **8-turn golden age**. Bases were chosen so as not to collide with the civs' own VP unique units: Poland's Winged Hussar and Pancerny, Austria's Hussar, Germany's Landsknecht, and England's Longbowman and Ship of the Line.

## More formation options

- **Several routes to one nation, each with its own flavour and bonus.** For the German Empire: the **dynastic** route through the HRE, the **economic** route through Zollverein cohesion, or **"blood and iron"** by annexation. For Italy: Rome or Venice leading the Risorgimento.
- **Successor states.** When a union or state dissolves, neighbours or the seceding partner can claim formations of their own.
- **Content rules.** No formations based on Nazi-era or other genocidal regimes. Colonial-era formations only where the subject is the polity itself and is presented neutrally, not as conquest of a living people.

## Implementation

- Data-driven: tables `FormableNations`, `FormableNation_ClaimGroups` and `FormableNation_Claims`. New content is SQL only.
- One InGameUIAddin context holds everything: `UI/FormableNations.lua` (turn hook, overlay, tabbed panel) includes `FN_Core.lua` (data, claims, formation), `FN_Cohesion.lua` (bonds, equilibrium, crises, secession), `FN_Organisations.lua` and `FN_Independence.lua` (provinces, movements, breakaways). The modules share the global table `FN`.
- `build.py` checks Lua syntax, XML, SQL references, text keys and settings, then runs the offline harness. After that it packages and installs.
- The SQL check runs against `tests/stub.py`. It holds base-game and VP names (`tests/stub_rows.sql`: all 120 City-States, `MajorBlocksMinor`, units, promotions, building classes) and `Policies`/`Units` tables with exactly the columns VP's DLL reads, taken from `CvPolicyClasses.cpp`/`CvUnitClasses.cpp` in `upstream/`. A misspelt column or an unknown City-State fails the build instead of showing up only in `Database.log`.
- Persistent state: whether a stage is formed comes from the player having its policy. Formation turns and the original names are stored in `Modding.OpenSaveData()`. Names are re-applied on load.
- Single-player only for now. UI-triggered state changes would desync multiplayer, which would need a network-safe path (`Network.SendLuaEvent`-style custom mission or DLL hooks).

## Content (v0.4)

| Chain | Stage | Era window | Claims | Bonus (dummy policy) |
|---|---|---|---|---|
| Poland | Union of Krewo (Tier I) | Medieval – Renaissance | `UNION` Vilnius | Capital +2 Culture, +2 Faith |
| Poland | Polish–Lithuanian Commonwealth (II) | Renaissance – Industrial | Krewo partners integrated 10 turns; `ABSORB` Vilnius | +1 World Congress vote; +5% Culture |
| Austria | Habsburg Monarchy (I) | Renaissance – Industrial | `UNION` Budapest or Bratislava | +5% Gold |
| Austria | Austria-Hungary (II) | Industrial – Modern | Habsburg partners integrated 10 turns; `ABSORB` Budapest or Bratislava (a married city-state counts and stays) | +5% Production, +5% Science |
| Germany | Holy Roman Empire (I) | Medieval – Renaissance | `ALLY` Vatican City *or* `OWN` Rome's capital; `UNION` 2 of Wittenberg, Prague, Zurich, Geneva, Milan, Genoa, Florence, Antwerp, Brussels | +10% Faith; Capital +2 Culture |
| Germany | German Empire (II) | Industrial – Modern | `ABSORB` Wittenberg | +5% Production; +10% military unit production |
| England | Union of the Crowns (I) | Renaissance – Industrial | `UNION` Edinburgh, or the Celts as vassal | Capital +2 Culture, +2 Gold |
| England | Great Britain (II) | Renaissance – Industrial | Union of the Crowns partners integrated 10 turns; `ABSORB` Edinburgh, or own the Celtic capital / Celts as vassal | +5% Gold; +1 movement for embarked units |

The bonuses above are the v0.2 base. v0.3 adds unique units, economic perks and proclamation golden ages (see "Perks of formed nations").

**More nations (v0.5)**, for civilizations that had none. Where a civ's homeland City-State is blocked while it plays, the claim pairs that City-State with the civ's capital:

| Civ | Nation (tier) | Era window | Claims |
|---|---|---|---|
| Arabia | Abbasid Caliphate (II) | Medieval – Renaissance | `ABSORB` 2 of Sidon, Tyre, Byblos |
| Assyria | Neo-Assyrian Empire (II) | Ancient – Classical | `ABSORB` 1 of Sidon, Tyre, Byblos |
| Persia | Achaemenid Empire (II) | Ancient – Classical | `ABSORB` Ur, or `OWN` Babylon's capital |
| Carthage | Covenant of Melqart (I) | Ancient – Classical | `UNION` 1 of Tyre, Sidon, Byblos |
| Byzantium | Renovatio Imperii (II) | Classical – Medieval | Palatium or Rome's capital; Utica or Carthage's capital |
| France | Grand Empire (I) | Renaissance – Industrial | `UNION` 2 of Wittenberg, Milan, Zurich, Geneva, Brussels, Warsaw |
| Portugal / Brazil | United Kingdom of Portugal, Brazil and the Algarves (I) | Renaissance – Industrial | the other: its City-State (Rio / Lisbon) or its civ as vassal |
| Indonesia | Majapahit Mandala (I) | Medieval – Renaissance | `UNION` 2 of Malacca, Singapore, Kuala Lumpur, Manila |
| Siam | Ayutthaya Mandala (I) | Medieval – Renaissance | `UNION` 2 of Malacca, Kuala Lumpur, Singapore (competes with Majapahit) |
| Morocco | Saadi Sultanate (II) | Renaissance | `ABSORB` Djenne, or `OWN` Songhai's capital |
| Ottomans | Kayser-i Rum (II) | Medieval – Renaissance | `OWN` Byzantium's capital, or `ABSORB` Perge |
| Venice | Stato da Mar (I) | Medieval – Renaissance | `UNION` 2 of Ragusa, Tyre, Sidon, Valletta (unions only: VP's Venice cannot annex) |

New organisations: the Tributary System (functional, Classical–Industrial; only China can found it, via `FounderCivilization`), the Non-Aligned Movement (intergovernmental, Atomic+) and the Covenant Chain (alliance).

**Historical City-States and the cap.** With many formations, the swap cap (50% of City-States) must be shared. Human players' formations come first; AI civs then get one swap each per round.

**More nations (v0.4)**, one or two claim steps each, spread across the eras:

| Civ | Nation (tier) | Era window | Claims | Bonus |
|---|---|---|---|---|
| Babylon | Kingdom of Sumer and Akkad (II) | Ancient – Classical | `ABSORB` Ur | Capital +2 Science, +2 Food |
| Denmark | Kalmar Union (I) | Medieval – Renaissance | `UNION` Stockholm, or Sweden as vassal | Capital +2 Production, +2 Gold |
| Sweden | Swedish Empire (II) | Renaissance – Industrial | `ABSORB` Riga | +10% military production; capital +2 Culture |
| Russia | Russian Empire (II) | Renaissance – Industrial | `ABSORB` Riga (competes with Sweden) | +5% Science; capital +2 Culture |
| Spain | Iberian Union (I) | Renaissance | `UNION` Lisbon, or Portugal as vassal | +5% Gold |
| Netherlands | United Kingdom of the Netherlands (II) | Industrial | `ABSORB` Brussels or Antwerp | +5% Production; capital +3 Gold |
| Rome | Kingdom of Italy (II) | Industrial – Modern | `ABSORB` 2 of Florence, Milan, Genoa, Venice | +5% Culture; capital +3 Culture |
| Mongolia | Yuan Dynasty (II) | Medieval – Renaissance | `OWN` China's capital | +5% Gold, +5% Science |

Organisations: European Coal and Steel Community, European Economic Community and European Union (the European chain above), Hanseatic League (Medieval–Renaissance), OPEC (Atomic+), Arab League (Modern+), African Union, ASEAN, Nordic Council (Atomic+), Mercosur (Information+).

Candidates for more nations (data only): the Arab Caliphate (Jerusalem + Levant); the Ottoman Caliphate (Jerusalem + Mecca or Thebes); Yuan (Mongolia + China's capital); Kingdom of Italy (Rome or Venice + 2 of Florence/Milan/Genoa); Swedish Empire (Riga); Russian Empire (Riga; competes with Sweden and Poland as in the Northern Wars); United Kingdom of the Netherlands (Brussels or Antwerp); Iberian Union (Spain + Portugal's capital); Kalmar Union (Denmark + Sweden's capital); Kingdom of Sumer and Akkad (Babylon + Ur); Restored Roman Empire (Byzantium + Rome's capital or Carthage's capital).

## Localisation

The mod ships English (`Text/FN_Text_en_US.xml`) and German (`Text/FN_Text_de_DE.xml`, table `Language_DE_DE`). The German file uses the base game's formal address ("Ihr/Euer") and terms (Einfluss, Stadtstaat, Goldenes Zeitalter, Handelsweg). Civ names a formation renames to carry the base game's grammatical forms: `_DESC` has 3 forms separated by `|`, `_ADJ` has 5, and `_SHORT` has `Plurality` (and `Gender` where feminine). The base game's sentences pick forms by index (`{1_CivAdj[3]}`). `build.py` checks that every translation has exactly the English keys and placeholders, and that these forms are complete. Other languages fall back to English while `DisableFallbackLanguageSupport = 0`.
