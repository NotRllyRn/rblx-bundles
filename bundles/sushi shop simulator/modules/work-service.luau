local WorkService = {}
WorkService.__index = WorkService

local function getStationDistance(rootPart, station)
	local standHere = station:FindFirstChild("StandHere")
	return standHere and (rootPart.Position - standHere.Position).Magnitude or math.huge
end

function WorkService.new(
	refs,
	settings,
	state,
	movement,
	occupancy,
	recipeService,
	signals,
	log,
	tipService
)
	return setmetatable({
		refs = refs,
		settings = settings,
		state = state,
		movement = movement,
		occupancy = occupancy,
		recipeService = recipeService,
		signals = signals,
		log = log,
		tipService = tipService,
		character = nil,
		activityValues = {},
	}, WorkService)
end

function WorkService:setCharacter(character)
	self.character = character
	table.clear(self.activityValues)
end

function WorkService:_getActivityValue(valueName)
	local cachedValue = self.activityValues[valueName]
	if cachedValue and cachedValue.Parent then
		return cachedValue
	end

	local character = self.character or self.state.character
	if not character or not character.Parent then
		self.activityValues[valueName] = nil
		return nil
	end

	local valueObject = character:FindFirstChild(valueName)
	if valueObject and valueObject:IsA("ValueBase") and typeof(valueObject.Value) == "number" then
		self.activityValues[valueName] = valueObject
		return valueObject
	end

	return nil
end

function WorkService:isBusy()
	for _, valueName in { "Making", "Washing" } do
		local valueObject = self:_getActivityValue(valueName)
		if valueObject and valueObject.Value ~= 0 then
			return true
		end
	end

	return false
end

function WorkService:_nearestAvailableStation(stations, predicate)
	if not self.movement:isReady() then
		return nil
	end

	local nearestStation = nil
	local nearestDistance = math.huge

	for _, station in stations do
		if
			self.state:isTargetAllowed(station)
			and self.occupancy:isAvailable(station)
			and (predicate == nil or predicate(station))
		then
			local distance = getStationDistance(self.movement.rootPart, station)
			if distance < nearestDistance then
				nearestStation = station
				nearestDistance = distance
			end
		end
	end

	return nearestStation
end

function WorkService:_waitForCharacterAction(valueName, finishTimeout)
	local valueObject = self:_getActivityValue(valueName)
	if not valueObject then
		return nil, `Missing character activity value {valueName}`
	end

	local started = valueObject.Value ~= 0
	if not started then
		started = self.signals.waitForValue(valueObject, function(currentValue)
			return currentValue ~= 0
		end, self.settings.Timing.ActionStartTimeout)
	end

	if not started then
		return false, `Timed out waiting for {valueName} to start`
	end

	local finished = valueObject.Value == 0 or self.signals.waitForValue(valueObject, function(currentValue)
		return currentValue == 0
	end, finishTimeout)

	if not finished then
		return false, `Timed out waiting for {valueName} to finish`
	end

	return true
end

function WorkService:_useStation(station, actionName)
	local standHere = station:FindFirstChild("StandHere")
	local detector = station:FindFirstChild("ClickDetector")
	if not standHere or not detector then
		return false
	end

	local function remainsAvailable()
		return station.Parent ~= nil and self.occupancy:isAvailable(station)
	end

	if not remainsAvailable() then
		return false
	end

	if not self.movement:isWithinRange(standHere, detector.MaxActivationDistance) then
		self.log:action(`Moving to {actionName} at {station.Name}`)
		local reached = self.movement:moveWithinClickRange(
			standHere,
			detector.MaxActivationDistance,
			remainsAvailable
		)

		if not reached or not remainsAvailable() then
			self.state:blacklistTarget(station, self.settings.Timing.TargetBlacklist)
			self.log:debug(`Abandoned {station.Name} because it became unavailable or unreachable`)
			return false
		end
	end

	fireclickdetector(detector)
	task.wait(self.settings.Timing.InteractionDebounce)
	return true
end

function WorkService:cook()
	local recipe = self.recipeService:selectBestRecipe()
	if not recipe then
		return false
	end

	local station = self:_nearestAvailableStation(self.state.cookStations, function(candidate)
		local requiredLevel = candidate:FindFirstChild("Level")
		return requiredLevel ~= nil and requiredLevel.Value <= self.refs.level.Value
	end)

	if not station or not self:_useStation(station, `cook {recipe.name}`) then
		return false
	end

	self.log:action(`Cooking {recipe.name}`)
	local cooked, problem = self:_waitForCharacterAction(
		"Making",
		recipe.cookSeconds + self.settings.Timing.CookBuffer
	)
	if cooked == nil then
		self.log:warn(problem)
		task.wait(recipe.cookSeconds + self.settings.Timing.CookBuffer)
		return true
	end

	if not cooked or self.refs.gameover.Value then
		self.state:blacklistTarget(station, self.settings.Timing.TargetBlacklist)
		self.log:warn(`Cooking {recipe.name} was not confirmed at {station.Name}: {problem}`)
		return false
	end

	return true
end

function WorkService:washDish()
	if self.refs.dirtyPlates.Value <= 0 then
		return false
	end

	local sink = self:_nearestAvailableStation(self.state.sinks)
	if not sink then
		return false
	end

	local previousDirtyPlates = self.refs.dirtyPlates.Value
	if not self:_useStation(sink, "wash a dish") then
		return false
	end

	local washed, problem = self:_waitForCharacterAction("Washing", self.settings.Timing.WashTimeout)
	if washed == nil then
		self.log:warn(problem)
		washed = self.signals.waitUntilChanged(
			self.refs.dirtyPlates,
			previousDirtyPlates,
			self.settings.Timing.WashTimeout
		)
	end

	if washed then
		self.log:action("Washed one dirty plate")
		return true
	end

	self.state:blacklistTarget(sink, self.settings.Timing.TargetBlacklist)
	self.log:warn(`Dish washing was not confirmed at {sink.Name}: {problem}`)
	
	return false
end

function WorkService:rest(shouldRemainSeated)
	for _, seat in self.state.sofaSeats do
		if seat.Parent and seat.Occupant == nil and self.movement:sitInSeat(seat) then
			self.log:action("Resting on the staff-room sofa")

			while
				seat.Parent
				and seat.Occupant == self.movement.humanoid
				and shouldRemainSeated()
			do
				task.wait(self.settings.Timing.NightRestRecheck)
			end

			if self.movement.humanoid then
				self.movement.humanoid.Sit = false
			end
			return true
		end
	end

	return false
end

function WorkService:claimTips()
	return self.tipService:claimWithMovement(self.movement)
end

return WorkService
