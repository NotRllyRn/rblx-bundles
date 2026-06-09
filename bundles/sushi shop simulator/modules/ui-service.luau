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

function UiService:_pressPlayButtonIfOpen()
	local screenGui = self.refs.playerGui:FindFirstChild("ScreenGui")
	local frame = screenGui and screenGui:FindFirstChild("Frame")
	local playButton = frame and frame:FindFirstChild("play")
	if not screenGui or not frame or not playButton then
		return false
	end

	if screenGui.Enabled == false or frame.Visible == false then
		return false
	end

	local pressed = false
	if typeof(firesignal) == "function" and playButton:IsA("GuiButton") then
		pressed = pcall(function()
			firesignal(playButton.MouseButton1Click)
		end)

		if not pressed then
			pressed = pcall(function()
				firesignal(playButton.Activated)
			end)
		end
	end

	if pressed then
		self.log:action("Pressed the play button")
		return true
	end

	return false
end

function UiService:closeBlockingGui()
	local closedGui = false
	if self:_pressPlayButtonIfOpen() then
		closedGui = true
	end

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
