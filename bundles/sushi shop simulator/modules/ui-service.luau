local UiService = {}
UiService.__index = UiService

function UiService.new(refs, settings, log)
	return setmetatable({
		refs = refs,
		settings = settings,
		log = log,
	}, UiService)
end

function UiService:_restoreMovement()
	local character = self.refs.localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = self.settings.Movement.DefaultWalkSpeed
	end
end

function UiService:closeBlockingGui()
	local closedGui = false
	local newDay = self.refs.playerGui:FindFirstChild("NewDay")
	if newDay then
		newDay:Destroy()
		closedGui = true
		self.log:debug("Closed the day transition message")
	end

	local incomeStatement = self.refs.playerGui:FindFirstChild("IncomeStatementGUI")
	if incomeStatement and not self.refs.gameover.Value then
		incomeStatement:Destroy()
		closedGui = true
		self.log:action("Closed the income statement")
	end

	if closedGui then
		self:_restoreMovement()
		task.wait(self.settings.Timing.ModalCloseDelay)
	end

	return closedGui
end

return UiService
