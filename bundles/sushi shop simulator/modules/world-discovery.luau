local HOURS_PER_HALF_DAY = 12
local HOURS_PER_DAY = 24
local MINUTES_PER_HOUR = 60

local WorldDiscovery = {}
WorldDiscovery.__index = WorldDiscovery

local function hasNamedChildren(instance, childNames)
	for _, childName in childNames do
		if not instance:FindFirstChild(childName) then
			return false
		end
	end
	return true
end

local function isCookStation(instance)
	return instance:IsA("Model") and hasNamedChildren(instance, {
		"Base",
		"Spawn",
		"Spawn2",
		"StandHere",
		"Level",
		"CookingScript",
		"ClickDetector",
	})
end

local function isSink(instance)
	return instance:IsA("Model") and hasNamedChildren(instance, {
		"Base",
		"StandHere",
		"SinkScript",
		"ClickDetector",
	})
end

local function getModelPosition(model)
	return model:GetPivot().Position
end

local function parseClockText(text)
	local hourText, minuteText, meridiem = string.match(text, "^(%d+):(%d+)%s*([AP]M)$")
	if not hourText then
		return nil
	end

	local hour = tonumber(hourText)
	local minute = tonumber(minuteText)
	if not hour or not minute then
		return nil
	end

	hour %= HOURS_PER_HALF_DAY
	if meridiem == "PM" then
		hour += HOURS_PER_HALF_DAY
	end

	return hour + minute / MINUTES_PER_HOUR
end

function WorldDiscovery.new(refs, settings, log)
	return setmetatable({
		refs = refs,
		settings = settings,
		log = log,
		clockLabel = nil,
	}, WorldDiscovery)
end

function WorldDiscovery:_findSofaSeats()
	local nearestModel = nil
	local nearestDistance = math.huge

	for _, descendant in self.refs.workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "Model" then
			local meshPart = descendant:FindFirstChildWhichIsA("MeshPart")
			local sofaSeatCount = 0

			for _, child in descendant:GetChildren() do
				if child:IsA("Seat") and child.Name == "Sofa" then
					sofaSeatCount += 1
				end
			end

			if meshPart and sofaSeatCount >= 2 then
				local distance = (getModelPosition(descendant) - self.settings.SofaPosition).Magnitude
				if distance < nearestDistance then
					nearestModel = descendant
					nearestDistance = distance
				end
			end
		end
	end

	local seats = {}
	if nearestModel then
		for _, child in nearestModel:GetChildren() do
			if child:IsA("Seat") and child.Name == "Sofa" then
				table.insert(seats, child)
			end
		end
	end

	return seats
end

function WorldDiscovery:_findClockLabel()
	for _, descendant in self.refs.workspace:GetDescendants() do
		if descendant:IsA("TextLabel") and parseClockText(descendant.Text) then
			local ancestor = descendant.Parent
			while ancestor and ancestor ~= self.refs.workspace do
				if ancestor.Name == "time2" then
					return descendant
				end
				ancestor = ancestor.Parent
			end
		end
	end

	return nil
end

function WorldDiscovery:discover()
	local cookStations = {}
	local sinks = {}

	for _, child in self.refs.gameFolder:GetChildren() do
		if isCookStation(child) then
			table.insert(cookStations, child)
		elseif isSink(child) then
			table.insert(sinks, child)
		end
	end

	self.clockLabel = self:_findClockLabel()
	local result = {
		cookStations = cookStations,
		sinks = sinks,
		sofaSeats = self:_findSofaSeats(),
		tipJar = self.refs.gameFolder:FindFirstChild("TipJar"),
	}

	self.log:info(
		`Discovered {#cookStations} cook stations, {#sinks} sinks, and {#result.sofaSeats} sofa seats`
	)
	return result
end

function WorldDiscovery:getClockTime()
	local lightingTime = self.refs.lighting.ClockTime
	if lightingTime >= 0 and lightingTime < HOURS_PER_DAY then
		return lightingTime
	end

	if self.clockLabel and self.clockLabel.Parent then
		return parseClockText(self.clockLabel.Text)
	end

	self.clockLabel = self:_findClockLabel()
	return self.clockLabel and parseClockText(self.clockLabel.Text) or nil
end

function WorldDiscovery:isShopOpen()
	local clockTime = self:getClockTime()
	if clockTime == nil then
		self.log:warn("Could not determine the current shop time")
		return false
	end

	return clockTime >= self.settings.Hours.Open and clockTime < self.settings.Hours.Close
end

return WorldDiscovery
