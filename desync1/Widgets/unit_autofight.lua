local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Auto Fight",
		desc      = "Auto cloaks Units with Cloak",
		author    = "wilkubyk",
		layer     = -99999,
		enabled   = true
	}
end

local myTeamID = Spring.GetMyTeamID()
local myUnitDefID = UnitDefNames['cloakraid'].id
local fightAreaX = Game.mapSizeX - 1000
local fightAreaY = 1000
local spawn = {}
local initialized = myTeamID == 0 and 0 or 3
spawn[1] = {fightAreaX - 400, fightAreaY - 500}
spawn[2] = {fightAreaX + 400, fightAreaY + 500}

local nextOrder = math.random(0, 59)

Spring.SelectUnitArray({})

-- dyntrainer_strike_base
-- 
local function rand()
	return (math.random()-0.5)*2.0
end

local defIdToName = {}
for i,v in pairs(UnitDefs) do
	Spring.Echo("DEF", v.id, v.name)
	defIdToName[v.id] = v.name
end

local function hasFighters()
	local units = Spring.GetAllUnits()
	for i, unitID in ipairs(units) do
		local defid = Spring.GetUnitDefID(unitID)
		if defid == myUnitDefID then
			return true
		end
	end
	return false
end

local function MoveUnit(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	local side = math.random(50, 500)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, {fightAreaX +  side * rand(), y, fightAreaY + side * rand()})
end

local function isCommander(unitDefID)
	local defName = defIdToName[unitDefID]
	if defName == 'dyntrainer_strike_base' or defName == 'dyntrainer_assault_base' or defName == 'dyntrainer_support_base' or defName == 'dyntrainer_recon_base' then
		return true
	end
	return false
end

local function GiveBuildOrders(unitID)
	local defID = UnitDefNames['energysolar'].id
	for i=1,10 do
		local x = fightAreaX + rand()*250
		local z = fightAreaY + rand()*250
		local y = Spring.GetGroundHeight(x, z)
		Spring.GiveOrderToUnit(unitID, -defID, {x, y, z}, CMD.OPT_SHIFT)
	end
end

local function GiveSelectedLineOrder()
	local area = 100
	local opts = 0
	if rand() > 0.0 then
		opts = {'shift'}
		--opts = {'shift', 'ctrl'}
	end
	local bx = fightAreaX+rand()*area
	local by = fightAreaY+rand()*area
	Spring.GiveOrder(CMD.MOVE, {bx, 100, by, bx+math.random()*area, 100, by+math.random()*area}, opts)
end

local function initialize(reason, gf)
	if gf and gf < 1 then
		return
	end
	Spring.Echo("Initialize", reason, gf)
	if not hasFighters() then
		if initialized == 0 then
			if not Spring.IsCheatingEnabled() then
				Spring.SendCommands('cheat on')
				Spring.SendCommands('luaui reload')
			end
			initialized = initialized + 1
		elseif initialized == 2 then
			local x = fightAreaX + 700
			local z = fightAreaY
			Spring.SendCommands('give 30 cloakraid 0 @4000,100,1000')
			Spring.SendCommands('give 30 cloakraid 1 @5000,100,500')
			Spring.SendCommands('give 1 factoryspider 0 @'..x..',100,'..z)
			Spring.SelectUnitArray({})
		end
		if gf > 10 then
			initialized = initialized + 1
		end
	else
		local x = fightAreaX + 700
		local z = fightAreaY
		Spring.SendCommands('give 1 factoryspider 0 @'..x..',100,'..z)
		initialized = 3
	end
end

function widget:GameStart()
	--initialize("Start")
end

function widget:DrawScreen()
	--Spring.Echo('point', gl.GetFixedState("pointSmooth"))
	--Spring.Echo(gl.GetFixedState("lineSmooth"))
end

local function PrintUnits()
	local units = Spring.GetSelectedUnits()
	local unitID = units[1]
	Spring.Echo(Spring.Utilities.json.encode(units), unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID then
		Spring.Echo(defIdToName[unitDefID])
	end
end

function widget:GameFrame(gf)
	if initialized < 3 then
		initialize("Frame", gf)
		return
	end
	local units = Spring.GetAllUnits()
	for i, unitID in pairs(units) do
		local teamID = Spring.GetUnitTeam(unitID)
		if teamID and teamID == myTeamID and ((unitID % 100) == (gf % 100)) then
			local defid = Spring.GetUnitDefID(unitID)
			--Spring.Echo(defid)
			if isCommander(defid) and Spring.GetUnitCommandCount(unitID) < 2 then
				-- GiveBuildOrders(unitID)
			end
			if defid == myUnitDefID and not Spring.IsUnitSelected(unitID) then
				--Spring.Echo("My unit", unitID)
				--MoveUnit(unitID)
			end
		end
	end
	if gf%60 == nextOrder then
		--print("next order", Spring.GetSelectedUnitsCount(), myTeamID)
		if Spring.GetSelectedUnitsCount() == 1 then
			PrintUnits()
			return
		end
		--print("next order2", Spring.GetSelectedUnitsCount())
		nextOrder = math.random(0, 59)
		for i, unitID in pairs(units) do
			local teamID = Spring.GetUnitTeam(unitID)
			--Spring.Echo(teamID, myTeamID)
			if teamID == myTeamID then
				local defid = Spring.GetUnitDefID(unitID)
				--print("next order3", unitID, defid, myUnitDefID)
				if defid == myUnitDefID then
					if rand() > 0.0 then
						Spring.SelectUnit(unitID, true)
					else
						Spring.DeselectUnit(unitID)
					end
				else
					Spring.DeselectUnit(unitID)
				end
			end
		end
		GiveSelectedLineOrder()
	end
end

function widget:Initialize()
	myTeamID = Spring.GetMyTeamID()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local sx = spawn[myTeamID+1][1] + rand()*50
	local sy = spawn[myTeamID+1][2] + rand()*50
	if unitTeam == myTeamID then -- and unitDefID == myUnitDefID then
		local defName = defIdToName[unitDefID]
		if defName == 'spiderscout' then
			return
		end
		local udef = UnitDefNames[defName]
		if udef.isBuilding then
			Spring.Echo("not respawning", defName)
			return
		end
		Spring.SendCommands('give 1 '..defIdToName[unitDefID]..' '..tostring(myTeamID)..' @'..tostring(sx)..',100,'..tostring(sy))
	end
end

local function GiveBuildSpiderOrders(unitID)
	local defID = UnitDefNames['spiderscout'].id
	for i=1,10 do
		--local x = fightAreaX + rand()*250
		--local z = fightAreaY + rand()*250
		--local y = Spring.GetGroundHeight(x, z)
		Spring.GiveOrderToUnit(unitID, -defID, {}, CMD.OPT_SHIFT+CMD.OPT_CTRL)
	end
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, {fightAreaX, 100, fightAreaY}, CMD.OPT_SHIFT+CMD.OPT_CTRL)

end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		if isCommander(unitDefID) then
			GiveBuildOrders(unitID)
		end
	end
	if unitTeam == myTeamID and unitDefID == UnitDefNames['factoryspider'].id then
		GiveBuildSpiderOrders(unitID)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
end

function widget:PlayerChanged(playerID)
	myTeamID = playerID
end


