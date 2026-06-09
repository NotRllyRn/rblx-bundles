local MonitorSchema = require("./monitor-schema")

local MonitorController = {}
MonitorController.__index = MonitorController

local function deepClone(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[key] = deepClone(child)
	end
	return copy
end

local function copyInto(target, source)
	for key in target do
		if source[key] == nil then
			target[key] = nil
		end
	end
	for key, value in source do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			copyInto(target[key], value)
		else
			target[key] = value
		end
	end
end

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function getPath(root, path)
	local value = root
	for _, part in splitPath(path) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

local function setPath(root, path, value)
	local parts = splitPath(path)
	local target = root
	for index = 1, #parts - 1 do
		target = target[parts[index]]
		if type(target) ~= "table" then
			return false
		end
	end
	target[parts[#parts]] = value
	return true
end

local function parseValue(field, rawValue)
	if field.kind == "boolean" then
		if type(rawValue) == "boolean" then
			return rawValue
		end
		local lowered = string.lower(tostring(rawValue))
		if lowered == "true" or lowered == "on" or lowered == "1" then
			return true
		elseif lowered == "false" or lowered == "off" or lowered == "0" then
			return false
		end
		return nil, "Expected true or false"
	elseif field.kind == "number" or field.kind == "integer" then
		local number = tonumber(rawValue)
		if not number then
			return nil, "Expected a number"
		end
		if field.kind == "integer" and number % 1 ~= 0 then
			return nil, "Expected a whole number"
		end
		if field.min ~= nil and number < field.min then
			return nil, `Minimum is {field.min}`
		end
		if field.max ~= nil and number > field.max then
			return nil, `Maximum is {field.max}`
		end
		return number
	elseif field.kind == "choice" then
		for _, choice in field.choices do
			if rawValue == choice then
				return rawValue
			end
		end
		return nil, `Choose one of: {table.concat(field.choices, ", ")}`
	end

	local text = tostring(rawValue)
	if text == "" then
		return nil, "Value cannot be empty"
	end
	return text
end

function MonitorController.new(application)
	return setmetatable({
		application = application,
		settings = application.settings,
		startupSettings = deepClone(application.settings),
	}, MonitorController)
end

function MonitorController:_fieldForPath(path)
	local sectionKey, fieldPath = string.match(path, "^([^.]+)%.(.+)$")
	if not sectionKey then
		return nil
	end

	for _, section in MonitorSchema.sections do
		if section.key == sectionKey then
			for _, field in MonitorSchema.getFields(section, self.settings) do
				if field.key == fieldPath then
					return field
				end
			end
		end
	end
	return nil
end

function MonitorController:getSetting(path)
	return getPath(self.settings, path)
end

function MonitorController:setSetting(path, rawValue)
	local field = self:_fieldForPath(path)
	if not field then
		return false, "This setting is read-only"
	end

	local value, problem = parseValue(field, rawValue)
	if problem then
		return false, problem
	end
	if not setPath(self.settings, path, value) then
		return false, "Setting path no longer exists"
	end

	self.application:_refreshSettingReferences()
	self.application.state:setTelemetry("lastAction", `Changed {path}`)
	self.application.state:wake()
	return true
end

function MonitorController:resetSection(sectionKey)
	local startupSection = self.startupSettings[sectionKey]
	local currentSection = self.settings[sectionKey]
	if type(startupSection) ~= "table" or type(currentSection) ~= "table" then
		return false
	end

	copyInto(currentSection, startupSection)
	self.application:_refreshSettingReferences()
	self.application.state:setTelemetry("lastAction", `Reset {sectionKey} settings`)
	self.application.state:wake()
	return true
end

function MonitorController:resetAll()
	copyInto(self.settings, self.startupSettings)
	self.application:_refreshSettingReferences()
	self.application.state:setTelemetry("lastAction", "Reset all settings")
	self.application.state:wake()
end

function MonitorController:subscribe(callback)
	return self.application.state:subscribe(callback)
end

function MonitorController:subscribeLog(callback)
	return self.application.log:subscribe(callback)
end

function MonitorController:getLogs()
	return self.application.log:getHistory()
end

function MonitorController:_stationSummary(stations)
	local available = 0
	for _, station in stations do
		if self.application.occupancy:isAvailable(station) then
			available += 1
		end
	end
	return {
		total = #stations,
		available = available,
	}
end

function MonitorController:getSnapshot()
	local app = self.application
	local refs = app.refs
	local stock = {}

	for stockName, threshold in self.settings.StockThresholds do
		local valueObject = refs.stock:FindFirstChild(stockName)
		local price = valueObject and valueObject:FindFirstChild("Price")
		table.insert(stock, {
			name = stockName,
			value = valueObject and valueObject.Value or 0,
			threshold = threshold,
			price = price and price.Value or nil,
		})
	end
	table.sort(stock, function(left, right)
		return left.name < right.name
	end)

	local bestRecipe = app.recipeService:getBestCraftableRecipe()
	local currentRecipe = app.recipeData:get(refs.recipe.Value)
	local clockTime = app.world:getClockTime()
	local shopOpen = clockTime ~= nil
		and clockTime >= self.settings.Hours.Open
		and clockTime < self.settings.Hours.Close

	return {
		paused = app.state.controls.paused,
		busy = app.workService:isBusy(),
		gameover = refs.gameover.Value,
		shopOpen = shopOpen,
		clockTime = clockTime,
		energy = refs.energy.Value,
		level = refs.level.Value,
		bank = refs.bank.Value,
		sales = refs.sales.Value,
		wallet = refs.cents.Value,
		day = refs.days.Value,
		plates = refs.plates.Value,
		dirtyPlates = refs.dirtyPlates.Value,
		currentRecipe = currentRecipe and currentRecipe.name or `Recipe {refs.recipe.Value}`,
		bestRecipe = bestRecipe and bestRecipe.name or "None craftable",
		cookStations = self:_stationSummary(app.state.cookStations),
		sinks = self:_stationSummary(app.state.sinks),
		sofaSeats = {
			total = #app.state.sofaSeats,
			available = (function()
				local count = 0
				for _, seat in app.state.sofaSeats do
					if seat.Parent and seat.Occupant == nil then
						count += 1
					end
				end
				return count
			end)(),
		},
		tips = app.tipService.tips and app.tipService.tips.Value or 0,
		stock = stock,
		restock = app.restockService:getPreview(),
		telemetry = table.clone(app.state.telemetry),
	}
end

function MonitorController:togglePaused()
	local app = self.application
	app.state.controls.paused = not app.state.controls.paused
	if app.state.controls.paused then
		app.movement:cancelCurrentMove()
	end
	app.state:setTelemetry(
		"lastAction",
		app.state.controls.paused and "Paused automation" or "Resumed automation"
	)
	app.state:wake()
end

function MonitorController:wakeNow()
	self.application.state:setTelemetry("lastAction", "Manual wake requested")
	self.application.state:wake()
end

function MonitorController:refreshWorld()
	task.spawn(function()
		local success, problem = pcall(function()
			self.application:_discoverWorld()
		end)
		if not success then
			self.application.log:warn(`Manual world refresh failed: {problem}`)
		end
	end)
end

function MonitorController:claimTipsNow()
	task.spawn(function()
		local claimed = self.application.workService:claimTips()
		if not claimed then
			self.application.log:info("No tips were available to claim")
		end
		self.application.state:wake()
	end)
end

return MonitorController
