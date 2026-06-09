local PathfindingService = game:GetService("PathfindingService")

local Movement = {}
Movement.__index = Movement

local function getPosition(target)
	if typeof(target) == "Vector3" then
		return target
	end

	if target:IsA("BasePart") then
		return target.Position
	end

	if target:IsA("Model") then
		return target:GetPivot().Position
	end

	error(`Unsupported movement target: {target.ClassName}`)
end

function Movement.new(config, log)
	return setmetatable({
		config = config,
		log = log,
		character = nil,
		humanoid = nil,
		rootPart = nil,
		moveId = 0,
		traversalCallback = nil,
		statusCallback = nil,
	}, Movement)
end

function Movement:setCharacter(character)
	self:cancelCurrentMove()
	self.character = character
	self.humanoid = character and character:FindFirstChildOfClass("Humanoid")
	self.rootPart = character and character:FindFirstChild("HumanoidRootPart")
end

function Movement:setTraversalCallback(callback)
	self.traversalCallback = callback
end

function Movement:setStatusCallback(callback)
	self.statusCallback = callback
end

function Movement:isReady()
	return self.character ~= nil
		and self.character.Parent ~= nil
		and self.humanoid ~= nil
		and self.humanoid.Health > 0
		and self.rootPart ~= nil
end

function Movement:cancelCurrentMove()
	self.moveId += 1

	if self.humanoid then
		self.humanoid:Move(Vector3.zero)
	end
end

function Movement:_canContinue(moveId, shouldContinue)
	if moveId ~= self.moveId or not self:isReady() then
		return false
	end

	return shouldContinue == nil or shouldContinue()
end

function Movement:_runTraversalCallback()
	if self.traversalCallback and self.rootPart then
		local success, problem = pcall(self.traversalCallback, self.rootPart.Position)
		if not success then
			self.log:warn(`Traversal callback failed: {problem}`)
		end
	end
end

function Movement:_standUpIfSeated()
	if not self.humanoid or (not self.humanoid.Sit and self.humanoid.SeatPart == nil) then
		return
	end

	self.humanoid.Sit = false
	local deadline = os.clock() + self.config.UnsitTimeout

	while
		self:isReady()
		and (self.humanoid.Sit or self.humanoid.SeatPart ~= nil)
		and os.clock() < deadline
	do
		task.wait(self.config.PollInterval)
	end
end

function Movement:_moveToWaypoint(position, moveId, shouldContinue)
	if not self:_canContinue(moveId, shouldContinue) then
		return false
	end

	local reached = false
	local finished = false
	local connection = self.humanoid.MoveToFinished:Connect(function(success)
		reached = success
		finished = true
	end)

	self.humanoid:MoveTo(position)
	local deadline = os.clock() + self.config.WaypointTimeout

	while not finished and os.clock() < deadline do
		if not self:_canContinue(moveId, shouldContinue) then
			break
		end

		self:_runTraversalCallback()
		task.wait(self.config.PollInterval)
	end

	connection:Disconnect()
	return reached
end

function Movement:_followPath(destination, arrivalRadius, moveId, shouldContinue)
	local path = PathfindingService:CreatePath({
		AgentRadius = self.config.AgentRadius,
		AgentHeight = self.config.AgentHeight,
		AgentCanJump = self.config.AgentCanJump,
		AgentCanClimb = self.config.AgentCanClimb,
		WaypointSpacing = self.config.WaypointSpacing,
	})

	local computed, problem = pcall(function()
		path:ComputeAsync(self.rootPart.Position, destination)
	end)

	if not computed or path.Status ~= Enum.PathStatus.Success then
		self.log:debug(`Path computation failed: {problem or path.Status.Name}`)
		return false
	end

	local blocked = false
	local blockedConnection = path.Blocked:Connect(function()
		blocked = true
	end)

	for _, waypoint in path:GetWaypoints() do
		if not self:_canContinue(moveId, shouldContinue) or blocked then
			blockedConnection:Disconnect()
			return false
		end

		if (self.rootPart.Position - destination).Magnitude <= arrivalRadius then
			blockedConnection:Disconnect()
			return true
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			self.humanoid.Jump = true
		end

		if not self:_moveToWaypoint(waypoint.Position, moveId, shouldContinue) then
			blockedConnection:Disconnect()
			return false
		end
	end

	blockedConnection:Disconnect()
	return (self.rootPart.Position - destination).Magnitude <= arrivalRadius
end

function Movement:isWithinRange(target, radius)
	if not self:isReady() then
		return false
	end

	return (self.rootPart.Position - getPosition(target)).Magnitude <= radius
end

function Movement:moveToTarget(target, arrivalRadius, shouldContinue)
	if not self:isReady() then
		return false
	end

	local destination = getPosition(target)
	if self.statusCallback then
		self.statusCallback(destination)
	end
	local radius = arrivalRadius or self.config.ArrivalRadius
	self.moveId += 1
	local moveId = self.moveId

	if (self.rootPart.Position - destination).Magnitude <= radius then
		self:_runTraversalCallback()
		return true
	end

	self:_standUpIfSeated()

	for _ = 1, self.config.RepathRetries do
		if self:_followPath(destination, radius, moveId, shouldContinue) then
			self:_runTraversalCallback()
			return true
		end

		if not self:_canContinue(moveId, shouldContinue) then
			return false
		end
	end

	return false
end

function Movement:moveWithinClickRange(target, maxDistance, shouldContinue)
	local minimumArrivalRadius = 1
	local clickRangeBuffer = 1
	local distance = math.max(
		minimumArrivalRadius,
		math.min(self.config.ArrivalRadius, maxDistance - clickRangeBuffer)
	)
	return self:moveToTarget(target, distance, shouldContinue)
end

function Movement:sitInSeat(seat)
	if not self:isReady() or seat.Occupant ~= nil then
		return false
	end

	local reachedSeat = self:moveToTarget(seat, self.config.SeatRadius, function()
		return seat.Occupant == nil
	end)

	if seat.Occupant == self.humanoid then
		return true
	end

	if not reachedSeat then
		return false
	end

	if seat.Occupant ~= nil then
		return false
	end

	seat:Sit(self.humanoid)

	local deadline = os.clock() + self.config.WaypointTimeout
	while os.clock() < deadline do
		if seat.Occupant == self.humanoid then
			return true
		end
		task.wait(self.config.PollInterval)
	end

	return false
end

return Movement
