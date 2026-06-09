local TipService = {}
TipService.__index = TipService

local function getTarget(tipJar)
	if not tipJar then
		return nil
	end

	return tipJar:FindFirstChild("Head")
		or tipJar.PrimaryPart
		or tipJar:FindFirstChildWhichIsA("BasePart", true)
end

function TipService.new(settings, log)
	return setmetatable({
		settings = settings,
		log = log,
		tipJar = nil,
		tips = nil,
		detector = nil,
		target = nil,
		lastClaimAttempt = 0,
	}, TipService)
end

function TipService:setTipJar(tipJar)
	self.tipJar = tipJar
	self.tips = tipJar and tipJar:FindFirstChild("Tips")
	self.detector = tipJar and tipJar:FindFirstChildWhichIsA("ClickDetector", true)
	self.target = getTarget(tipJar)
end

function TipService:hasTips()
	return self.tips ~= nil and self.tips.Value > 0
end

function TipService:tryClaimNearby(position)
	if not self:hasTips() or not self.detector or not self.target then
		return false
	end

	local now = os.clock()
	if now - self.lastClaimAttempt < self.settings.Timing.TipJarDebounce then
		return false
	end

	if (position - self.target.Position).Magnitude > self.detector.MaxActivationDistance then
		return false
	end

	self.lastClaimAttempt = now
	fireclickdetector(self.detector)
	self.log:action("Claimed tips while passing the tip jar")
	return true
end

function TipService:claimWithMovement(movement)
	if not self:hasTips() or not self.detector or not self.target then
		return false
	end

	if not movement:moveWithinClickRange(self.target, self.detector.MaxActivationDistance) then
		return false
	end

	return self:tryClaimNearby(movement.rootPart.Position)
end

return TipService
