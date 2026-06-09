local MonitorSchema = require("./monitor-schema")

local MonitorUi = {}
MonitorUi.__index = MonitorUi

local REFRESH_INTERVAL = 0.25
local Rayfield = nil

local THEME = {
	TextColor = Color3.fromRGB(246, 238, 216),
	Background = Color3.fromRGB(27, 25, 22),
	Topbar = Color3.fromRGB(48, 37, 30),
	Shadow = Color3.fromRGB(12, 11, 10),
	NotificationBackground = Color3.fromRGB(38, 34, 29),
	NotificationActionsBackground = Color3.fromRGB(230, 216, 184),
	TabBackground = Color3.fromRGB(52, 48, 41),
	TabStroke = Color3.fromRGB(78, 70, 58),
	TabBackgroundSelected = Color3.fromRGB(195, 75, 54),
	TabTextColor = Color3.fromRGB(218, 207, 181),
	SelectedTabTextColor = Color3.fromRGB(255, 248, 229),
	ElementBackground = Color3.fromRGB(42, 39, 34),
	ElementBackgroundHover = Color3.fromRGB(54, 49, 42),
	SecondaryElementBackground = Color3.fromRGB(34, 32, 28),
	ElementStroke = Color3.fromRGB(72, 65, 54),
	SecondaryElementStroke = Color3.fromRGB(58, 53, 45),
	SliderBackground = Color3.fromRGB(65, 83, 69),
	SliderProgress = Color3.fromRGB(106, 151, 118),
	SliderStroke = Color3.fromRGB(130, 174, 139),
	ToggleBackground = Color3.fromRGB(33, 31, 27),
	ToggleEnabled = Color3.fromRGB(104, 154, 117),
	ToggleDisabled = Color3.fromRGB(105, 96, 82),
	ToggleEnabledStroke = Color3.fromRGB(135, 184, 145),
	ToggleDisabledStroke = Color3.fromRGB(130, 119, 101),
	ToggleEnabledOuterStroke = Color3.fromRGB(80, 108, 85),
	ToggleDisabledOuterStroke = Color3.fromRGB(68, 62, 53),
	DropdownSelected = Color3.fromRGB(77, 91, 71),
	DropdownUnselected = Color3.fromRGB(39, 37, 32),
	InputBackground = Color3.fromRGB(31, 29, 26),
	InputStroke = Color3.fromRGB(85, 75, 61),
	PlaceholderColor = Color3.fromRGB(152, 139, 116),
}

local function formatClock(clockTime)
	if clockTime == nil then
		return "Unknown"
	end

	local hour = math.floor(clockTime)
	local minute = math.floor((clockTime - hour) * 60 + 0.5)
	if minute >= 60 then
		hour = (hour + 1) % 24
		minute = 0
	end

	local meridiem = hour >= 12 and "PM" or "AM"
	local displayHour = hour % 12
	if displayHour == 0 then
		displayHour = 12
	end
	return string.format("%d:%02d %s", displayHour, minute, meridiem)
end

local function formatOptional(value)
	return value == nil and "Unknown" or tostring(value)
end

local function formatTelemetry(telemetry)
	return table.concat({
		`Current task: {formatOptional(telemetry.currentTask)}`,
		`Last decision: {formatOptional(telemetry.lastDecision)}`,
		`Last action: {formatOptional(telemetry.lastAction)}`,
		`Last success: {formatOptional(telemetry.lastSuccess)}`,
		`Last failure: {formatOptional(telemetry.lastFailure)}`,
		`Movement target: {formatOptional(telemetry.lastMovementTarget)}`,
		`World refresh: {formatOptional(telemetry.lastWorldRefresh)}`,
	}, "\n")
end

local function formatLogs(history)
	local lines = {}
	local first = math.max(1, #history - 11)
	for index = #history, first, -1 do
		local entry = history[index]
		table.insert(lines, `[{entry.level}] {entry.message}`)
	end
	return #lines > 0 and table.concat(lines, "\n") or "No log entries yet."
end

function MonitorUi.new(controller, log)
	return setmetatable({
		controller = controller,
		log = log,
		mounted = false,
		dirty = true,
		unsubscribers = {},
		settingElements = {},
		stockParagraphs = {},
	}, MonitorUi)
end

function MonitorUi:_notify(title, content, image)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 5,
		Image = image or "info",
	})
end

function MonitorUi:_runAction(title, callback)
	task.spawn(function()
		local success, result, detail = pcall(callback)
		if not success then
			self:_notify(`${title} failed`, tostring(result), "triangle-alert")
			return
		end

		local content = result == false and (detail or "Nothing actionable was found.") or "Action completed."
		self:_notify(title, content, result == false and "info" or "circle-check")
		self.dirty = true
	end)
end

function MonitorUi:_createSetting(tab, field)
	local currentValue = self.controller:getSetting(field.path)
	local element

	if field.kind == "boolean" then
		element = tab:CreateToggle({
			Name = field.label,
			CurrentValue = currentValue,
			Callback = function(value)
				local success, problem = self.controller:setSetting(field.path, value)
				if not success then
					self:_notify("Invalid setting", problem, "triangle-alert")
				end
			end,
		})
	elseif field.kind == "dropdown" then
		element = tab:CreateDropdown({
			Name = field.label,
			Options = field.options,
			CurrentOption = { currentValue },
			MultipleOptions = false,
			Callback = function(options)
				local success, problem = self.controller:setSetting(field.path, options)
				if not success then
					self:_notify("Invalid setting", problem, "triangle-alert")
				end
			end,
		})
	else
		element = tab:CreateInput({
			Name = field.label,
			CurrentValue = tostring(currentValue),
			PlaceholderText = field.kind == "number" and "Enter a number" or "Enter text",
			RemoveTextAfterFocusLost = false,
			Callback = function(text)
				local success, result = self.controller:setSetting(field.path, text)
				if success then
					return
				end

				self:_notify("Invalid setting", result, "triangle-alert")
				local previousValue = self.controller:getSetting(field.path)
				if tostring(text) ~= tostring(previousValue) then
					element:Set(tostring(previousValue))
				end
			end,
		})
	end

	self.settingElements[field.path] = element
end

function MonitorUi:_syncSettingElements(sectionKey)
	for _, section in MonitorSchema.getSections() do
		if sectionKey == nil or section.key == sectionKey then
			for _, field in section.fields do
				local element = self.settingElements[field.path]
				local value = self.controller:getSetting(field.path)
				if field.kind == "dropdown" then
					element:Set({ value })
				else
					element:Set(field.kind == "boolean" and value or tostring(value))
				end
			end
		end
	end
end

function MonitorUi:_buildOverview(window)
	local tab = window:CreateTab("Overview", "activity")
	tab:CreateSection("Automation")
	self.statusParagraph = tab:CreateParagraph({ Title = "Status", Content = "Starting..." })
	self.telemetryParagraph = tab:CreateParagraph({ Title = "Runtime", Content = "Waiting for telemetry..." })
	tab:CreateSection("Shop")
	self.shopParagraph = tab:CreateParagraph({ Title = "Shop Snapshot", Content = "Reading game values..." })
	self.worldParagraph = tab:CreateParagraph({ Title = "World", Content = "Discovering stations..." })
end

function MonitorUi:_buildInventory(window)
	local tab = window:CreateTab("Inventory", "package")
	tab:CreateSection("Restock")
	self.restockParagraph = tab:CreateParagraph({ Title = "Next Restock", Content = "No preview yet." })
	tab:CreateSection("Current Stock")
	for _, field in MonitorSchema.getSection("StockThresholds").fields do
		local stockName = string.split(field.path, ".")[2]
		self.stockParagraphs[stockName] = tab:CreateParagraph({
			Title = field.label,
			Content = "Reading stock...",
		})
	end
end

function MonitorUi:_buildSettings(window)
	local tab = window:CreateTab("Settings", "settings")
	for _, section in MonitorSchema.getSections() do
		local sectionKey = section.key
		local sectionTitle = section.title
		tab:CreateSection(section.title)
		for _, field in section.fields do
			self:_createSetting(tab, field)
		end
		tab:CreateButton({
			Name = `Reset {sectionTitle}`,
			Callback = function()
				local success, problem = self.controller:resetSection(sectionKey)
				if success then
					self:_syncSettingElements(sectionKey)
					self:_notify("Settings reset", `{sectionTitle} restored to startup values`, "rotate-ccw")
				else
					self:_notify("Reset failed", problem, "triangle-alert")
				end
			end,
		})
	end
end

function MonitorUi:_buildActions(window)
	local tab = window:CreateTab("Actions", "wrench")
	tab:CreateSection("Automation")
	self.pauseToggle = tab:CreateToggle({
		Name = "Pause Automation",
		CurrentValue = false,
		Callback = function(paused)
			self.controller:setPaused(paused)
		end,
	})
	tab:CreateButton({
		Name = "Wake Loop",
		Callback = function()
			self.controller:wake()
		end,
	})
	tab:CreateSection("Utilities")
	tab:CreateButton({
		Name = "Refresh World",
		Callback = function()
			self:_runAction("World refreshed", function()
				return self.controller:refreshWorld()
			end)
		end,
	})
	tab:CreateButton({
		Name = "Close Blocking Game UI",
		Callback = function()
			self:_runAction("Game UI check", function()
				return self.controller:closeBlockingGui()
			end)
		end,
	})
	tab:CreateButton({
		Name = "Claim Tips",
		Callback = function()
			self:_runAction("Tip claim", function()
				return self.controller:claimTips()
			end)
		end,
	})
	tab:CreateSection("Settings")
	tab:CreateButton({
		Name = "Reset All Settings",
		Callback = function()
			self.controller:resetAll()
			self:_syncSettingElements()
			self:_notify("Settings reset", "All settings restored to startup values", "rotate-ccw")
		end,
	})
end

function MonitorUi:_buildLogs(window)
	local tab = window:CreateTab("Logs", "scroll-text")
	tab:CreateSection("Highlights")
	self.latestActionParagraph = tab:CreateParagraph({ Title = "Latest Action", Content = "None yet." })
	self.latestWarningParagraph = tab:CreateParagraph({ Title = "Latest Warning", Content = "None yet." })
	tab:CreateSection("Recent Events")
	self.logsParagraph = tab:CreateParagraph({ Title = "Newest First", Content = "No log entries yet." })
end

function MonitorUi:_render()
	local success, snapshot = pcall(function()
		return self.controller:getSnapshot()
	end)
	if not success then
		self.log:warn(`Monitor snapshot failed: {snapshot}`)
		return
	end

	local runState = snapshot.paused and "PAUSED" or "RUNNING"
	local shopState = snapshot.gameover and "GAME OVER" or snapshot.shopOpen and "OPEN" or "CLOSED"
	self.statusParagraph:Set({
		Title = `{runState} | Shop {shopState}`,
		Content = `Character ready: {snapshot.movementReady}\nBusy: {snapshot.busy}\nTime: {formatClock(snapshot.clockTime)}`,
	})
	self.telemetryParagraph:Set({ Title = "Runtime", Content = formatTelemetry(snapshot.telemetry) })
	self.shopParagraph:Set({
		Title = "Shop Snapshot",
		Content = table.concat({
			`Energy: {snapshot.energy}`,
			`Level: {snapshot.level} | Day: {snapshot.day}`,
			`Recipe: {snapshot.equippedRecipe}`,
			`Best craftable: {snapshot.bestRecipe}`,
			`Bank: {snapshot.bank} | Sales: {snapshot.sales} | Wallet: {snapshot.wallet}`,
			`Clean plates: {snapshot.cleanPlates} | Dirty plates: {snapshot.dirtyPlates}`,
			`Tips: {snapshot.tips}`,
		}, "\n"),
	})
	self.worldParagraph:Set({
		Title = "World",
		Content = table.concat({
			`Cook stations: {snapshot.availableCookStations}/{snapshot.cookStations} available`,
			`Sinks: {snapshot.availableSinks}/{snapshot.sinks} available`,
			`Sofa seats: {snapshot.sofaSeats}`,
		}, "\n"),
	})

	local restock = snapshot.restock
	self.restockParagraph:Set({
		Title = restock and restock.name or "No Restock Needed",
		Content = restock
			and `Current: {restock.current}\nCost: {restock.cost}\nPayment: {restock.paymentSource or "unaffordable"}\nActionable: {restock.actionable}`
			or "All configured stock thresholds are currently satisfied.",
	})
	for _, item in snapshot.stock do
		local paragraph = self.stockParagraphs[item.name]
		if paragraph then
			paragraph:Set({
				Title = item.low and `{item.name} | LOW` or item.name,
				Content = `Current: {item.current}\nThreshold: {item.threshold}\nUnit price: {formatOptional(item.price)}`,
			})
		end
	end

	local history = self.controller:getLogHistory()
	local latestAction = "None yet."
	local latestWarning = "None yet."
	for index = #history, 1, -1 do
		local entry = history[index]
		if latestAction == "None yet." and entry.level == "ACTION" then
			latestAction = entry.message
		elseif latestWarning == "None yet." and entry.level == "WARN" then
			latestWarning = entry.message
		end
		if latestAction ~= "None yet." and latestWarning ~= "None yet." then
			break
		end
	end
	self.latestActionParagraph:Set({ Title = "Latest Action", Content = latestAction })
	self.latestWarningParagraph:Set({ Title = "Latest Warning", Content = latestWarning })
	self.logsParagraph:Set({ Title = "Newest First", Content = formatLogs(history) })

	if self.pauseToggle.CurrentValue ~= snapshot.paused then
		self.pauseToggle:Set(snapshot.paused)
	end
end

function MonitorUi:mount()
	if self.mounted then
		return
	end

	local built, problem = pcall(function()
		Rayfield = Rayfield or require("@vendor/ui-libs/Rayfield")
		local window = Rayfield:CreateWindow({
			Name = "Sushi Shop Operator",
			Icon = "utensils",
			LoadingTitle = "Sushi Shop Operator",
			LoadingSubtitle = "Standalone automation monitor",
			ShowText = "Sushi Monitor",
			Theme = THEME,
			ToggleUIKeybind = Enum.KeyCode.RightShift,
			DisableRayfieldPrompts = true,
			ConfigurationSaving = {
				Enabled = false,
				FolderName = nil,
				FileName = "SushiShopOperator",
			},
			Discord = { Enabled = false },
			KeySystem = false,
		})

		self:_buildOverview(window)
		self:_buildInventory(window)
		self:_buildSettings(window)
		self:_buildActions(window)
		self:_buildLogs(window)
	end)
	if not built then
		if Rayfield then
			pcall(function()
				Rayfield:Destroy()
			end)
		end
		error(problem)
	end
	self.mounted = true

	table.insert(self.unsubscribers, self.controller:subscribe(function()
		self.dirty = true
	end))
	table.insert(self.unsubscribers, self.controller:subscribeLog(function()
		self.dirty = true
	end))

	task.spawn(function()
		while self.mounted do
			if self.dirty then
				self.dirty = false
				self:_render()
			end
			task.wait(REFRESH_INTERVAL)
			self.dirty = true
		end
	end)
end

function MonitorUi:destroy()
	if not self.mounted then
		return
	end
	self.mounted = false

	for _, unsubscribe in self.unsubscribers do
		unsubscribe()
	end
	table.clear(self.unsubscribers)
	if Rayfield then
		Rayfield:Destroy()
	end
end

return MonitorUi
