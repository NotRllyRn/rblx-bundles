local Settings = require("./settings")
local Log = require("./log")
local Refs = require("./refs")
local State = require("./state")
local Signals = require("./signals")
local Movement = require("./movement")
local RecipeData = require("./recipe-data")
local WorldDiscovery = require("./world-discovery")
local StationOccupancy = require("./station-occupancy")
local RecipeService = require("./recipe-service")
local RestockService = require("./restock-service")
local TipService = require("./tip-service")
local UiService = require("./ui-service")
local WorkService = require("./work-service")

local Application = {}
Application.__index = Application

function Application.new()
	local log = Log.new(Settings.Logging)
	local refs = Refs.create()
	local state = State.new()
	local movement = Movement.new(Settings.Movement, log)
	local recipeData = RecipeData.new(refs.sushiData)
	local world = WorldDiscovery.new(refs, Settings, log)
	local occupancy = StationOccupancy.new(refs, Settings.Occupancy, log, function()
		state:wake()
	end)
	local recipeService = RecipeService.new(
		refs,
		Settings,
		state,
		recipeData,
		Signals,
		log
	)
	local restockService = RestockService.new(refs, Settings, Signals, log)
	local tipService = TipService.new(Settings, log)
	local uiService = UiService.new(refs, Settings, log)
	local workService = WorkService.new(
		refs,
		Settings,
		state,
		movement,
		occupancy,
		recipeService,
		Signals,
		log,
		tipService
	)

	movement:setTraversalCallback(function(position)
		tipService:tryClaimNearby(position)
	end)

	return setmetatable({
		settings = Settings,
		log = log,
		refs = refs,
		state = state,
		movement = movement,
		world = world,
		occupancy = occupancy,
		restockService = restockService,
		tipService = tipService,
		uiService = uiService,
		workService = workService,
	}, Application)
end

function Application:_connectValue(valueObject)
	Signals.connect(valueObject:GetPropertyChangedSignal("Value"), function()
		self.state:wake()
	end, self.state.connections)
end

function Application:_connectCharacterActivity(valueObject)
	if not valueObject:IsA("ValueBase") or typeof(valueObject.Value) ~= "number" then
		return
	end

	Signals.connect(valueObject:GetPropertyChangedSignal("Value"), function()
		self.state:wake()
	end, self.state.characterConnections)
end

function Application:_setCharacter(character)
	Signals.disconnectAll(self.state.characterConnections)

	local humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	self.state.character = character
	self.state.humanoid = humanoid
	self.movement:setCharacter(character)
	self.workService:setCharacter(character)

	for _, activityName in { "Making", "Washing" } do
		local valueObject = character:FindFirstChild(activityName)
		if valueObject then
			self:_connectCharacterActivity(valueObject)
		end
	end

	Signals.connect(character.ChildAdded, function(child)
		if child.Name == "Making" or child.Name == "Washing" then
			self:_connectCharacterActivity(child)
			self.state:wake()
		end
	end, self.state.characterConnections)

	Signals.connect(humanoid.Died, function()
		self.movement:cancelCurrentMove()
		self.state:wake()
	end, self.state.characterConnections)

	self.state:wake()
end

function Application:_discoverWorld()
	Signals.disconnectAll(self.state.worldConnections)

	local worldState = self.world:discover()
	self.state.cookStations = worldState.cookStations
	self.state.sinks = worldState.sinks
	self.state.sofaSeats = worldState.sofaSeats
	self.state.tipJar = worldState.tipJar
	self.occupancy:setStations(worldState.cookStations, worldState.sinks)
	self.tipService:setTipJar(worldState.tipJar)

	for _, seat in worldState.sofaSeats do
		Signals.connect(seat:GetPropertyChangedSignal("Occupant"), function()
			self.state:wake()
		end, self.state.worldConnections)
	end

	if self.world.clockLabel then
		Signals.connect(self.world.clockLabel:GetPropertyChangedSignal("Text"), function()
			self.state:wake()
		end, self.state.worldConnections)
	end

	if self.tipService.tips then
		Signals.connect(self.tipService.tips:GetPropertyChangedSignal("Value"), function()
			self.state:wake()
		end, self.state.worldConnections)
	end

	self.state:wake()
end

function Application:_connectWakeSources()
	Signals.connect(self.refs.localPlayer.CharacterAdded, function(character)
		self:_setCharacter(character)
	end, self.state.connections)

	Signals.connect(self.refs.gameFolder.ChildAdded, function()
		self:_discoverWorld()
	end, self.state.connections)

	Signals.connect(self.refs.gameFolder.ChildRemoved, function()
		self:_discoverWorld()
	end, self.state.connections)

	Signals.connect(self.refs.playerGui.ChildAdded, function()
		self.state:wake()
	end, self.state.connections)

	Signals.connect(self.refs.players.PlayerAdded, function()
		self.state:wake()
	end, self.state.connections)

	Signals.connect(self.refs.players.PlayerRemoving, function()
		self.state:wake()
	end, self.state.connections)

	Signals.connect(self.refs.lighting:GetPropertyChangedSignal("ClockTime"), function()
		self.state:wake()
	end, self.state.connections)

	for _, valueObject in {
		self.refs.bank,
		self.refs.gameover,
		self.refs.energy,
		self.refs.level,
		self.refs.recipe,
		self.refs.sales,
		self.refs.cents,
		self.refs.days,
	} do
		self:_connectValue(valueObject)
	end

	for _, descendant in self.refs.stock:GetDescendants() do
		if descendant:IsA("ValueBase") then
			self:_connectValue(descendant)
		end
	end

	Signals.connect(self.refs.stock.DescendantAdded, function(descendant)
		if descendant:IsA("ValueBase") then
			self:_connectValue(descendant)
		end
		self.state:wake()
	end, self.state.connections)
end

function Application:_restForEnergy()
	return self.workService:rest(function()
		return self.refs.energy.Value <= self.settings.Energy.Resume
			and not self.refs.gameover.Value
	end)
end

function Application:_restUntilWorkAppears()
	return self.workService:rest(function()
		return not self.world:isShopOpen()
			and self.refs.dirtyPlates.Value <= 0
			and not self.restockService:hasActionableRestock()
			and not self.refs.gameover.Value
	end)
end

function Application:_runNextTask()
	if self.refs.gameover.Value or not self.movement:isReady() then
		return false
	end

	if self.uiService:closeBlockingGui() then
		return true
	end

	if self.workService:isBusy() then
		return false
	end

	if self.refs.energy.Value <= self.settings.Energy.Minimum then
		return self:_restForEnergy()
	end

	if self.restockService:restockNext() then
		return true
	end

	if self.world:isShopOpen() then
		if self.refs.plates.Value <= 0 and self.refs.dirtyPlates.Value > 0 then
			return self.workService:washDish()
		end

		if self.refs.plates.Value > 0 and self.workService:cook() then
			return true
		end
	else
		if self.refs.dirtyPlates.Value > 0 and self.workService:washDish() then
			return true
		end

		if self:_restUntilWorkAppears() then
			return true
		end
	end

	return self.workService:claimTips()
end

function Application:run()
	shared.sushi_shop_simulator_loop = true
	self:_setCharacter(self.refs.localPlayer.Character or self.refs.localPlayer.CharacterAdded:Wait())
	self:_discoverWorld()
	self:_connectWakeSources()
	self.occupancy:start()
	self.log:info("Automation loop started")

	while shared.sushi_shop_simulator_loop ~= false do
		self.state:waitForWork()

		local success, didWork = pcall(function()
			return self:_runNextTask()
		end)

		if not success then
			self.log:warn(`Task failed: {didWork}`)
		end

		if success and didWork then
			self.state:wake()
		else
			task.delay(self.settings.Timing.IdleRetry, function()
				self.state:wake()
			end)
		end
	end

	self.occupancy:stop()
	self.movement:cancelCurrentMove()
	Signals.disconnectAll(self.state.worldConnections)
	Signals.disconnectAll(self.state.characterConnections)
	Signals.disconnectAll(self.state.connections)
	self.log:info("Automation loop stopped")
end

return Application
