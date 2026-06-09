local State = {}
State.__index = State

function State.new()
	return setmetatable({
		wakeEvent = Instance.new("BindableEvent"),
		dirty = true,
		connections = {},
		characterConnections = {},
		worldConnections = {},
		wakeListeners = {},
		character = nil,
		humanoid = nil,
		cookStations = {},
		sinks = {},
		sofaSeats = {},
		tipJar = nil,
		blacklist = {},
		lastRecipeSwitch = 0,
		controls = {
			paused = false,
		},
		telemetry = {
			currentTask = "Starting",
			lastDecision = "Waiting for initialization",
			lastSuccess = nil,
			lastFailure = nil,
			lastMovementTarget = nil,
			lastSnapshotAt = os.clock(),
		},
	}, State)
end

function State:wake()
	self.dirty = true
	self.wakeEvent:Fire()
	for callback in self.wakeListeners do
		task.spawn(callback)
	end
end

function State:subscribeWake(callback)
	self.wakeListeners[callback] = true
	return function()
		self.wakeListeners[callback] = nil
	end
end

function State:setTelemetry(key, value)
	self.telemetry[key] = value
	self.telemetry.lastSnapshotAt = os.clock()
end

function State:waitForWork()
	if not self.dirty then
		self.wakeEvent.Event:Wait()
	end
	self.dirty = false
end

function State:blacklistTarget(target, duration)
	self.blacklist[target] = os.clock() + duration
end

function State:isTargetAllowed(target)
	local blockedUntil = self.blacklist[target]
	if blockedUntil and blockedUntil > os.clock() then
		return false
	end

	self.blacklist[target] = nil
	return target.Parent ~= nil
end

return State
