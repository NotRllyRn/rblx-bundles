local State = {}
State.__index = State

function State.new()
	return setmetatable({
		wakeEvent = Instance.new("BindableEvent"),
		dirty = true,
		connections = {},
		characterConnections = {},
		worldConnections = {},
		character = nil,
		humanoid = nil,
		cookStations = {},
		sinks = {},
		sofaSeats = {},
		tipJar = nil,
		blacklist = {},
		lastRecipeSwitch = 0,
		listeners = {},
		controls = {
			paused = false,
		},
		telemetry = {
			currentTask = "Starting",
			lastDecision = "Waiting for initialization",
			lastAction = nil,
			lastSuccess = nil,
			lastFailure = nil,
			lastMovementTarget = nil,
			lastWorldRefresh = nil,
			lastUpdatedAt = os.clock(),
		},
	}, State)
end

function State:_notify()
	for callback in self.listeners do
		task.spawn(callback)
	end
end

function State:wake()
	self.dirty = true
	self.wakeEvent:Fire()
	self:_notify()
end

function State:subscribe(callback)
	self.listeners[callback] = true
	return function()
		self.listeners[callback] = nil
	end
end

function State:setTelemetry(key, value)
	if self.telemetry[key] == value then
		return
	end

	self.telemetry[key] = value
	self.telemetry.lastUpdatedAt = os.clock()
	self:_notify()
end

function State:setPaused(paused)
	if self.controls.paused == paused then
		return
	end

	self.controls.paused = paused
	self:setTelemetry("currentTask", paused and "Paused" or "Resuming")
	self:setTelemetry(
		"lastDecision",
		paused and "Automation paused by the operator" or "Automation resumed by the operator"
	)
	self:wake()
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
