local MonitorController = {}
MonitorController.__index = MonitorController

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function getPath(root, path)
	local current = root
	for _, key in path do
		current = current[key]
		if current == nil then
			return nil
		end
	end
	return current
end

local function setPath(root, path, value)
	local current = root
	for index = 1, #path - 1 do
		current = current[path[index]]
		if type(current) ~= "table" then
			return false
		end
	end
	current[path[#path]] = value
	return true
end

function MonitorController.new(application)
	return setmetatable({
		application = application,
		defaults = deepCopy(application.settings),
		listeners = {},
		manualActionRunning = false,
	}, MonitorController)
end

function MonitorController:_notify()
	for callback in self.listeners do
		task.spawn(callback)
	end
end

function MonitorController:subscribe(callback)
	self.listeners[callback] = true
	local disconnectWake = self.application.state:subscribeWake(callback)
	local disconnectLog = self.application.log:subscribe(callback)
	callback()
	return function()
		self.listeners[callback] = nil
		disconnectWake()
		disconnectLog()
	end
end

function MonitorController:getSetting(path)
	return getPath(self.application.settings, path)
end

function MonitorController:setSetting(path, value)
	if not setPath(self.application.settings, path, value) then
		return false, "Setting path is unavailable"
	end
	self.application.state:wake()
	self:_notify()
	return true
end

function MonitorController:resetSection(sectionKey)
	local original = self.defaults[sectionKey]
	if type(original) ~= "table" then
		return false
	end
	self.application.settings[sectionKey] = deepCopy(original)
	self.application:_refreshSettingReferences()
	self.application.state:wake()
	self:_notify()
	return true
end

function MonitorController:resetAll()
	for key, value in self.defaults do
		self.application.settings[key] = deepCopy(value)
	end
	self.application:_refreshSettingReferences()
	self.application.state:wake()
	self:_notify()
end

function MonitorController:togglePaused()
	local controls = self.application.state.controls
	controls.paused = not controls.paused
	if controls.paused then
		self.application.movement:cancelCurrentMove()
	end
	self.application.state:setTelemetry("lastDecision", controls.paused and "Paused by operator" or "Resumed by operator")
	self.application.state:wake()
	self:_notify()
	return controls.paused
end

function MonitorController:wakeNow()
	self.application.state:setTelemetry("lastDecision", "Manual wake requested")
	self.application.state:wake()
	self:_notify()
end

function MonitorController:refreshWorld()
	self.application:_discoverWorld()
	self.application.state:setTelemetry("lastDecision", "World references refreshed")
	self:_notify()
end

function MonitorController:claimTipsNow()
	if not self.application.state.controls.paused then
		self.application.log:warn("Pause automation before running a manual action")
		return false
	end
	if self.manualActionRunning then
		self.application.log:warn("Another manual action is already running")
		return false
	end

	self.manualActionRunning = true
	task.spawn(function()
		local success, result = pcall(function()
			return self.application.workService:claimTips()
		end)
		self.manualActionRunning = false
		if not success then
			self.application.log:warn(`Manual tip claim failed: {result}`)
		elseif not result then
			self.application.log:debug("Manual tip claim found nothing actionable")
		end
		self:_notify()
	end)
	return true
end

function MonitorController:getSnapshot()
	local application = self.application
	local refs = application.refs
	local state = application.state
	local stock = {}

	for _, descendant in refs.stock:GetChildren() do
		if descendant:IsA("ValueBase") then
			local price = descendant:FindFirstChild("Price")
			table.insert(stock, {
				name = descendant.Name,
				value = descendant.Value,
				price = price and price.Value or nil,
				threshold = application.settings.StockThresholds[descendant.Name],
			})
		end
	end
	table.sort(stock, function(left, right)
		return left.name < right.name
	end)

	local bestRecipe = application.recipeService:getBestCraftableRecipe()
	local tips = application.tipService.tips
	local clockTime = application.world:getClockTime()
	return {
		paused = state.controls.paused,
		running = shared.sushi_shop_simulator_loop ~= false,
		busy = application.workService:isBusy(),
		gameover = refs.gameover.Value,
		shopOpen = clockTime ~= nil
			and clockTime >= application.settings.Hours.Open
			and clockTime < application.settings.Hours.Close,
		clockTime = clockTime,
		day = refs.days.Value,
		level = refs.level.Value,
		energy = refs.energy.Value,
		bank = refs.bank.Value,
		sales = refs.sales.Value,
		wallet = refs.cents.Value,
		plates = refs.plates.Value,
		dirtyPlates = refs.dirtyPlates.Value,
		recipeId = refs.recipe.Value,
		bestRecipe = bestRecipe and bestRecipe.name or "None craftable",
		tips = tips and tips.Value or 0,
		cookStations = #state.cookStations,
		sinks = #state.sinks,
		sofaSeats = #state.sofaSeats,
		telemetry = table.clone(state.telemetry),
		stock = stock,
		logs = application.log:getHistory(),
		manualActionRunning = self.manualActionRunning,
	}
end

return MonitorController
