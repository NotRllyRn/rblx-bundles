local StationOccupancy = {}
StationOccupancy.__index = StationOccupancy

local function getActiveRootPart(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return rootPart
end

local function isUsingStation(player, activityValueName)
	local character = player.Character
	local valueObject = character and character:FindFirstChild(activityValueName)

	return valueObject
		and valueObject:IsA("ValueBase")
		and typeof(valueObject.Value) == "number"
		and valueObject.Value ~= 0
		or false
end

function StationOccupancy.new(refs, config, log, wake)
	return setmetatable({
		refs = refs,
		config = config,
		log = log,
		wake = wake,
		records = {},
		running = false,
	}, StationOccupancy)
end

function StationOccupancy:setStations(cookStations, sinks)
	local retained = {}

	for _, station in cookStations do
		local record = self.records[station] or {
			occupied = false,
			occupantPlayer = nil,
			lastOccupiedAt = nil,
			lastVacatedAt = nil,
			availableAfter = 0,
			readyLogged = true,
		}
		record.activityValueName = "Making"
		retained[station] = record
	end

	for _, station in sinks do
		local record = self.records[station] or {
			occupied = false,
			occupantPlayer = nil,
			lastOccupiedAt = nil,
			lastVacatedAt = nil,
			availableAfter = 0,
			readyLogged = true,
		}
		record.activityValueName = "Washing"
		retained[station] = record
	end

	self.records = retained
	self:refresh()
end

function StationOccupancy:_findOccupant(station)
	local standHere = station:FindFirstChild("StandHere")
	if not standHere or not standHere:IsA("BasePart") then
		return nil
	end

	local record = self.records[station]
	local activityValueName = record and record.activityValueName

	for _, player in self.refs.players:GetPlayers() do
		if player ~= self.refs.localPlayer then
			local rootPart = getActiveRootPart(player)
			if
				rootPart
				and (rootPart.Position - standHere.Position).Magnitude <= self.config.StandHereRadius
				and activityValueName
				and isUsingStation(player, activityValueName)
			then
				return player
			end
		end
	end

	return nil
end

function StationOccupancy:_refreshStation(station, record)
	if not station.Parent then
		return
	end

	local now = os.clock()
	local occupant = self:_findOccupant(station)

	if occupant then
		local changed = not record.occupied or record.occupantPlayer ~= occupant
		record.occupied = true
		record.occupantPlayer = occupant
		record.lastOccupiedAt = now
		record.availableAfter = math.huge
		record.readyLogged = false

		if changed then
			self.log:debug(`{station.Name} occupied by {occupant.Name}`)
			self.wake()
		end
	elseif record.occupied then
		record.occupied = false
		record.occupantPlayer = nil
		record.lastVacatedAt = now
		record.availableAfter = now + self.config.VacancyCooldown
		record.readyLogged = false
		self.log:debug(`{station.Name} vacated; cooldown started`)
		self.wake()
	elseif not record.readyLogged and now >= record.availableAfter then
		record.readyLogged = true
		self.log:debug(`{station.Name} is available`)
		self.wake()
	end
end

function StationOccupancy:refresh()
	for station, record in self.records do
		self:_refreshStation(station, record)
	end
end

function StationOccupancy:isAvailable(station)
	local record = self.records[station]
	if not record or not station.Parent then
		return false
	end

	self:_refreshStation(station, record)
	return not record.occupied and os.clock() >= record.availableAfter
end

function StationOccupancy:start()
	if self.running then
		return
	end

	self.running = true
	task.spawn(function()
		while self.running and shared.sushi_shop_simulator_loop ~= false do
			self:refresh()
			task.wait(self.config.RefreshInterval)
		end
	end)
end

function StationOccupancy:stop()
	self.running = false
end

return StationOccupancy
