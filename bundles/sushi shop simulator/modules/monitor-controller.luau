local MonitorSchema = require("./monitor-schema")

local MonitorController = {}
MonitorController.__index = MonitorController

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function overwriteTable(target, source)
	for key in target do
		if source[key] == nil then
			target[key] = nil
		end
	end

	for key, value in source do
		if typeof(value) == "table" then
			if typeof(target[key]) ~= "table" then
				target[key] = {}
			end
			overwriteTable(target[key], value)
		else
			target[key] = value
		end
	end
end

local function resolveParent(root, path)
	local parts = string.split(path, ".")
	local current = root
	for index = 1, #parts - 1 do
		current = current[parts[index]]
		if typeof(current) ~= "table" then
			return nil, nil
		end
	end
	return current, parts[#parts]
end

local function countAvailable(occupancy, stations)
	local available = 0
	for _, station in stations do
		if occupancy:isAvailable(station) then
			available += 1
		end
	end
	return available
end

local function getValue(valueObject)
	return valueObject and valueObject.Value or nil
end

function MonitorController.new(application)
	return setmetatable({
		application = application,
		startupSettings = deepCopy(application.settings),
		destroyed = false,
	}, MonitorController)
end

function MonitorController:getSetting(path)
	local parent, key = resolveParent(self.application.settings, path)
	return parent and parent[key] or nil
end

function MonitorController:setSetting(path, rawValue)
	local valid, value, problem = MonitorSchema.validate(path, rawValue)
	if not valid then
		return false, problem
	end

	local settings = self.application.settings
	if path == "Hours.Open" and value >= settings.Hours.Close then
		return false, "Opening hour must be earlier than closing hour"
	elseif path == "Hours.Close" and value <= settings.Hours.Open then
		return false, "Closing hour must be later than opening hour"
	elseif path == "Energy.Minimum" and value >= settings.Energy.Resume then
		return false, "Rest-at energy must be below resume energy"
	elseif path == "Energy.Resume" and value <= settings.Energy.Minimum then
		return false, "Resume energy must be above rest-at energy"
	end

	local parent, key = resolveParent(self.application.settings, path)
	if not parent then
		return false, `Setting path is unavailable: {path}`
	end

	parent[key] = value
	self.application.state:setTelemetry("lastAction", `Changed {path} to {tostring(value)}`)
	self.application.state:wake()
	return true, value
end

function MonitorController:resetSection(sectionKey)
	local original = self.startupSettings[sectionKey]
	local current = self.application.settings[sectionKey]
	if typeof(original) ~= "table" or typeof(current) ~= "table" then
		return false, `Unknown settings section: {sectionKey}`
	end

	overwriteTable(current, original)
	self.application.state:setTelemetry("lastAction", `Reset {sectionKey} settings`)
	self.application.state:wake()
	return true
end

function MonitorController:resetAll()
	overwriteTable(self.application.settings, self.startupSettings)
	self.application.state:setTelemetry("lastAction", "Reset all settings")
	self.application.state:wake()
	return true
end

function MonitorController:subscribe(callback)
	return self.application.state:subscribe(callback)
end

function MonitorController:subscribeLog(callback)
	return self.application.log:subscribe(callback)
end

function MonitorController:getLogHistory()
	return self.application.log:getHistory()
end

function MonitorController:setPaused(paused)
	self.application.state:setPaused(paused)
	if paused then
		self.application.movement:cancelCurrentMove()
	end
	return true
end

function MonitorController:togglePaused()
	self:setPaused(not self.application.state.controls.paused)
	return self.application.state.controls.paused
end

function MonitorController:wake()
	self.application.state:wake()
	return true
end

function MonitorController:refreshWorld()
	self.application:_discoverWorld()
	return true
end

function MonitorController:closeBlockingGui()
	return self.application.uiService:closeBlockingGui()
end

function MonitorController:claimTips()
	if not self.application.state.controls.paused then
		return false, "Pause automation before starting a manual movement action."
	end
	return self.application.workService:claimTips()
end

function MonitorController:getSnapshot()
	local app = self.application
	local refs = app.refs
	local state = app.state
	local clockTime = app.world:getClockTime()
	local shopOpen = clockTime ~= nil
		and clockTime >= app.settings.Hours.Open
		and clockTime < app.settings.Hours.Close

	local stock = {}
	for stockName, threshold in app.settings.StockThresholds do
		local stockValue = refs.stock:FindFirstChild(stockName)
		local price = stockValue and stockValue:FindFirstChild("Price")
		table.insert(stock, {
			name = stockName,
			current = getValue(stockValue) or 0,
			threshold = threshold,
			price = getValue(price),
			low = stockValue ~= nil and stockValue.Value < threshold,
		})
	end
	table.sort(stock, function(left, right)
		return left.name < right.name
	end)

	local equippedRecipe = app.recipeData:get(refs.recipe.Value)
	local bestRecipe = app.recipeService:getBestCraftableRecipe()

	return {
		paused = state.controls.paused,
		movementReady = app.movement:isReady(),
		busy = app.workService:isBusy(),
		gameover = refs.gameover.Value,
		shopOpen = shopOpen,
		clockTime = clockTime,
		energy = refs.energy.Value,
		level = refs.level.Value,
		day = refs.days.Value,
		bank = refs.bank.Value,
		sales = refs.sales.Value,
		wallet = refs.cents.Value,
		cleanPlates = refs.plates.Value,
		dirtyPlates = refs.dirtyPlates.Value,
		tips = app.tipService.tips and app.tipService.tips.Value or 0,
		equippedRecipe = equippedRecipe and equippedRecipe.name or `Recipe #{refs.recipe.Value}`,
		bestRecipe = bestRecipe and bestRecipe.name or "None craftable",
		cookStations = #state.cookStations,
		availableCookStations = countAvailable(app.occupancy, state.cookStations),
		sinks = #state.sinks,
		availableSinks = countAvailable(app.occupancy, state.sinks),
		sofaSeats = #state.sofaSeats,
		restock = app.restockService:getPreview(),
		stock = stock,
		telemetry = table.clone(state.telemetry),
	}
end

function MonitorController:destroy()
	self.destroyed = true
end

return MonitorController
