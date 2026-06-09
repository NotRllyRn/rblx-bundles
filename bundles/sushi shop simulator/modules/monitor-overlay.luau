local UserInputService = game:GetService("UserInputService")

local Fusion = require("@vendor/Fusion")
local Schema = require("./monitor-schema")
local Theme = require("./monitor-theme")

local MonitorOverlay = {}
MonitorOverlay.__index = MonitorOverlay

local COLORS = Theme.Colors
local FONTS = Theme.Fonts
local TABS = { "Overview", "Stock", "Settings", "Logs" }

local function formatNumber(value)
	if type(value) ~= "number" then
		return tostring(value)
	end
	if math.abs(value) >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	end
	if math.abs(value) >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return string.format("%.2f", value):gsub("%.?0+$", "")
end

local function formatClock(clockTime)
	if type(clockTime) ~= "number" then
		return "--:--"
	end
	local hour = math.floor(clockTime) % 24
	local minute = math.floor((clockTime - math.floor(clockTime)) * 60 + 0.5) % 60
	local suffix = hour >= 12 and "PM" or "AM"
	local displayHour = hour % 12
	if displayHour == 0 then
		displayHour = 12
	end
	return string.format("%d:%02d %s", displayHour, minute, suffix)
end

local function pathKey(path)
	return table.concat(path, ".")
end

function MonitorOverlay.new(refs, controller)
	return setmetatable({
		refs = refs,
		controller = controller,
		scope = nil,
		gui = nil,
		unsubscribe = nil,
	}, MonitorOverlay)
end

function MonitorOverlay:_computed(scope, snapshot, callback)
	return scope:Computed(function(use)
		return callback(use(snapshot))
	end)
end

function MonitorOverlay:_corner(scope, radius)
	return scope:New("UICorner")({
		CornerRadius = radius or Theme.Radius,
	})
end

function MonitorOverlay:_stroke(scope, color, transparency)
	return scope:New("UIStroke")({
		Color = color or COLORS.Stroke,
		Transparency = transparency or 0,
		Thickness = 1,
	})
end

function MonitorOverlay:_padding(scope, horizontal, vertical)
	return scope:New("UIPadding")({
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
	})
end

function MonitorOverlay:_label(scope, properties)
	local children = properties[Fusion.Children]
	properties[Fusion.Children] = nil
	properties.BackgroundTransparency = properties.BackgroundTransparency or 1
	properties.BorderSizePixel = 0
	properties.FontFace = properties.FontFace or FONTS.Body
	properties.TextColor3 = properties.TextColor3 or COLORS.Text
	properties.TextSize = properties.TextSize or 13
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	properties[Fusion.Children] = children
	return scope:New("TextLabel")(properties)
end

function MonitorOverlay:_button(scope, text, callback, properties)
	properties = properties or {}
	properties.Text = text
	properties.AutoButtonColor = false
	properties.BackgroundColor3 = properties.BackgroundColor3 or COLORS.PanelSoft
	properties.BorderSizePixel = 0
	properties.FontFace = properties.FontFace or FONTS.Body
	properties.TextColor3 = properties.TextColor3 or COLORS.Text
	properties.TextSize = properties.TextSize or 12
	properties[Fusion.OnEvent("Activated")] = callback
	properties[Fusion.Children] = {
		self:_corner(scope, UDim.new(0, 8)),
		self:_stroke(scope, COLORS.Stroke, 0.35),
	}
	return scope:New("TextButton")(properties)
end

function MonitorOverlay:_statusChip(scope, snapshot, label, predicate, activeColor)
	return scope:New("Frame")({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = self:_computed(scope, snapshot, function(data)
			return predicate(data) and activeColor or COLORS.PanelSoft
		end),
		BorderSizePixel = 0,
		[Fusion.Children] = {
			self:_corner(scope, UDim.new(1, 0)),
			self:_padding(scope, 9, 0),
			self:_label(scope, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 24),
				Text = label,
				TextSize = 11,
				TextColor3 = self:_computed(scope, snapshot, function(data)
					return predicate(data) and COLORS.Backdrop or COLORS.TextMuted
				end),
			}),
		},
	})
end

function MonitorOverlay:_metricCard(scope, snapshot, label, valueCallback, accent)
	return scope:New("Frame")({
		Size = UDim2.new(0.5, -5, 0, 68),
		BackgroundColor3 = COLORS.PanelRaised,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			self:_corner(scope),
			self:_stroke(scope, accent or COLORS.Stroke, 0.45),
			self:_padding(scope, 12, 9),
			self:_label(scope, {
				Position = UDim2.fromOffset(0, 1),
				Size = UDim2.new(1, 0, 0, 18),
				Text = label,
				TextColor3 = COLORS.TextMuted,
				TextSize = 11,
			}),
			self:_label(scope, {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 28),
				Text = self:_computed(scope, snapshot, valueCallback),
				TextColor3 = accent or COLORS.Text,
				TextSize = 20,
				FontFace = FONTS.Heading,
			}),
		},
	})
end

function MonitorOverlay:_sectionTitle(scope, text)
	return self:_label(scope, {
		Size = UDim2.new(1, 0, 0, 28),
		Text = text,
		TextSize = 12,
		TextColor3 = COLORS.Amber,
		FontFace = FONTS.Heading,
	})
end

function MonitorOverlay:_overview(scope, snapshot)
	local content = scope:New("Frame")({
		Name = "Overview",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})

	local statusRow = scope:New("Frame")({
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			self:_statusChip(scope, snapshot, "RUNNING", function(data)
				return data.running and not data.paused
			end, COLORS.Jade),
			self:_statusChip(scope, snapshot, "PAUSED", function(data)
				return data.paused
			end, COLORS.Amber),
			self:_statusChip(scope, snapshot, "SHOP OPEN", function(data)
				return data.shopOpen
			end, COLORS.Jade),
			self:_statusChip(scope, snapshot, "BUSY", function(data)
				return data.busy
			end, COLORS.Vermilion),
		},
	})
	statusRow.Parent = content

	local metricGrid = scope:New("Frame")({
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 146),
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellPadding = UDim2.fromOffset(10, 10),
				CellSize = UDim2.new(0.5, -5, 0, 68),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			self:_metricCard(scope, snapshot, "ENERGY", function(data)
				return formatNumber(data.energy)
			end, COLORS.Jade),
			self:_metricCard(scope, snapshot, "SHOP CLOCK", function(data)
				return formatClock(data.clockTime)
			end, COLORS.Amber),
			self:_metricCard(scope, snapshot, "BUSINESS BANK", function(data)
				return "$" .. formatNumber(data.bank)
			end),
			self:_metricCard(scope, snapshot, "PERSONAL WALLET", function(data)
				return "$" .. formatNumber(data.wallet)
			end),
		},
	})
	metricGrid.Parent = content

	local decisionTitle = self:_sectionTitle(scope, "AUTOMATION DECISION")
	decisionTitle.LayoutOrder = 3
	decisionTitle.Parent = content
	scope:New("Frame")({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = COLORS.PanelRaised,
		BorderSizePixel = 0,
		Parent = content,
		[Fusion.Children] = {
			self:_corner(scope),
			self:_stroke(scope, COLORS.JadeDark, 0.15),
			self:_padding(scope, 12, 10),
			self:_label(scope, {
				Size = UDim2.new(1, 0, 0, 22),
				Text = self:_computed(scope, snapshot, function(data)
					return data.telemetry.currentTask or "Waiting"
				end),
				TextSize = 16,
				FontFace = FONTS.Heading,
			}),
			self:_label(scope, {
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 0, 40),
				Text = self:_computed(scope, snapshot, function(data)
					return data.telemetry.lastDecision or "No decision recorded yet"
				end),
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = COLORS.TextMuted,
				TextSize = 12,
			}),
			self:_label(scope, {
				Position = UDim2.fromOffset(0, 69),
				Size = UDim2.new(1, 0, 0, 16),
				Text = self:_computed(scope, snapshot, function(data)
					return `Best recipe: {data.bestRecipe}  |  Plates: {data.plates}/{data.dirtyPlates} dirty`
				end),
				TextColor3 = COLORS.Amber,
				TextSize = 11,
			}),
		},
	})

	local actionsTitle = self:_sectionTitle(scope, "OPERATOR ACTIONS")
	actionsTitle.LayoutOrder = 5
	actionsTitle.Parent = content
	local actionRow = scope:New("Frame")({
		LayoutOrder = 6,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		Parent = content,
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellPadding = UDim2.fromOffset(7, 0),
				CellSize = UDim2.new(0.25, -6, 1, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	self:_button(scope, self:_computed(scope, snapshot, function(data)
		return data.paused and "Resume" or "Pause"
	end), function()
		self.controller:togglePaused()
	end, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.JadeDark }).Parent = actionRow
	self:_button(scope, "Wake", function()
		self.controller:wakeNow()
	end, { Size = UDim2.fromScale(1, 1) }).Parent = actionRow
	self:_button(scope, "Refresh", function()
		self.controller:refreshWorld()
	end, { Size = UDim2.fromScale(1, 1) }).Parent = actionRow
	self:_button(scope, "Claim Tips", function()
		self.controller:claimTipsNow()
	end, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.Vermilion }).Parent = actionRow

	local discoveryTitle = self:_sectionTitle(scope, "DISCOVERY")
	discoveryTitle.LayoutOrder = 7
	discoveryTitle.Parent = content
	self:_label(scope, {
		LayoutOrder = 8,
		Size = UDim2.new(1, 0, 0, 22),
		Text = self:_computed(scope, snapshot, function(data)
			return `{data.cookStations} cook stations  |  {data.sinks} sinks  |  {data.sofaSeats} sofa seats  |  {formatNumber(data.tips)} tips`
		end),
		TextColor3 = COLORS.TextMuted,
		Parent = content,
	})

	return content
end

function MonitorOverlay:_stock(scope, snapshot)
	local content = scope:New("Frame")({
		Name = "Stock",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})

	self:_label(scope, {
		Size = UDim2.new(1, 0, 0, 42),
		Text = "Live inventory. Amber rows are below the configured restock threshold.",
		TextWrapped = true,
		TextColor3 = COLORS.TextMuted,
		Parent = content,
	})

	for _, stockName in {
		"Rice",
		"Vegetable",
		"Fish",
		"SoyaSauce",
		"PremFish",
		"Coffee",
		"Plates",
		"PlatesDirty",
	} do
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = self:_computed(scope, snapshot, function(data)
				for _, item in data.stock do
					if item.name == stockName then
						return item.threshold and item.value < item.threshold
							and Color3.fromRGB(72, 57, 31)
							or COLORS.PanelRaised
					end
				end
				return COLORS.PanelRaised
			end),
			BorderSizePixel = 0,
			Parent = content,
			[Fusion.Children] = {
				self:_corner(scope, UDim.new(0, 8)),
				self:_stroke(scope, COLORS.Stroke, 0.5),
				self:_padding(scope, 12, 0),
				self:_label(scope, {
					Size = UDim2.new(0.48, 0, 1, 0),
					Text = stockName,
					FontFace = FONTS.Heading,
				}),
				self:_label(scope, {
					Position = UDim2.new(0.48, 0, 0, 0),
					Size = UDim2.new(0.52, 0, 1, 0),
					Text = self:_computed(scope, snapshot, function(data)
						for _, item in data.stock do
							if item.name == stockName then
								local threshold = item.threshold and ` / {formatNumber(item.threshold)}` or ""
								local price = item.price and `  @ ${formatNumber(item.price)}` or ""
								return `{formatNumber(item.value)}{threshold}{price}`
							end
						end
						return "Unavailable"
					end),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = COLORS.TextMuted,
					FontFace = FONTS.Mono,
					TextSize = 12,
				}),
			},
		})
	end

	return content
end

function MonitorOverlay:_settingField(scope, snapshot, field)
	local errorState = scope:Value("")
	local row = scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			self:_label(scope, {
				Size = UDim2.new(0.56, 0, 1, 0),
				Text = field.label,
				TextColor3 = self:_computed(scope, errorState, function(problem)
					return problem == "" and COLORS.TextMuted or COLORS.Vermilion
				end),
				TextSize = 12,
			}),
		},
	})

	if field.kind == "boolean" then
		self:_button(scope, self:_computed(scope, snapshot, function()
			return self.controller:getSetting(field.path) and "ON" or "OFF"
		end), function()
			self.controller:setSetting(field.path, not self.controller:getSetting(field.path))
		end, {
			Position = UDim2.new(0.68, 0, 0, 5),
			Size = UDim2.new(0.32, 0, 0, 32),
			BackgroundColor3 = self:_computed(scope, snapshot, function()
				return self.controller:getSetting(field.path) and COLORS.JadeDark or COLORS.PanelSoft
			end),
		}).Parent = row
	elseif field.kind == "choice" then
		self:_button(scope, self:_computed(scope, snapshot, function()
			return tostring(self.controller:getSetting(field.path))
		end), function()
			local current = self.controller:getSetting(field.path)
			local nextIndex = 1
			for index, choice in field.choices do
				if choice == current then
					nextIndex = index % #field.choices + 1
					break
				end
			end
			self.controller:setSetting(field.path, field.choices[nextIndex])
		end, {
			Position = UDim2.new(0.56, 0, 0, 5),
			Size = UDim2.new(0.44, 0, 0, 32),
		}).Parent = row
	else
		local textBox
		local focused = false
		textBox = scope:New("TextBox")({
			Position = UDim2.new(0.62, 0, 0, 5),
			Size = UDim2.new(0.38, 0, 0, 32),
			BackgroundColor3 = COLORS.PanelSoft,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = FONTS.Mono,
			Text = self:_computed(scope, snapshot, function()
				if focused and textBox then
					return textBox.Text
				end
				return formatNumber(self.controller:getSetting(field.path))
			end),
			TextColor3 = COLORS.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			[Fusion.OnEvent("Focused")] = function()
				focused = true
			end,
			[Fusion.OnEvent("FocusLost")] = function()
				focused = false
				local value = tonumber(textBox.Text)
				if value == nil then
					errorState:set("Enter a number")
				elseif value < field.minimum or value > field.maximum then
					errorState:set(`Use {field.minimum}-{field.maximum}`)
				else
					if field.step and field.step >= 1 then
						value = math.round(value / field.step) * field.step
					end
					errorState:set("")
					self.controller:setSetting(field.path, value)
				end
				textBox.Text = formatNumber(self.controller:getSetting(field.path))
			end,
			[Fusion.Children] = {
				self:_corner(scope, UDim.new(0, 8)),
				self:_stroke(scope, self:_computed(scope, errorState, function(problem)
					return problem == "" and COLORS.Stroke or COLORS.Vermilion
				end), 0.25),
				self:_padding(scope, 9, 0),
			},
		})
		textBox.Parent = row
	end

	return row
end

function MonitorOverlay:_settings(scope, snapshot)
	local content = scope:New("Frame")({
		Name = "Settings",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})

	local resetAll = self:_button(scope, "Reset all session settings", function()
		self.controller:resetAll()
	end, {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = COLORS.Vermilion,
	})
	resetAll.Parent = content

	for sectionIndex, section in Schema do
		local sectionFrame = scope:New("Frame")({
			LayoutOrder = sectionIndex + 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = COLORS.PanelRaised,
			BorderSizePixel = 0,
			Parent = content,
			[Fusion.Children] = {
				self:_corner(scope),
				self:_stroke(scope, COLORS.Stroke, 0.45),
				self:_padding(scope, 12, 10),
				scope:New("UIListLayout")({
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			},
		})
		local header = scope:New("Frame")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Parent = sectionFrame,
			[Fusion.Children] = {
				self:_label(scope, {
					Size = UDim2.new(0.68, 0, 1, 0),
					Text = section.label,
					TextColor3 = COLORS.Amber,
					FontFace = FONTS.Heading,
					TextSize = 12,
				}),
			},
		})
		self:_button(scope, "Reset", function()
			self.controller:resetSection(section.key)
		end, {
			Position = UDim2.new(0.75, 0, 0, 2),
			Size = UDim2.new(0.25, 0, 0, 29),
			TextSize = 11,
		}).Parent = header

		for fieldIndex, field in section.fields do
			local fieldRow = self:_settingField(scope, snapshot, field)
			fieldRow.LayoutOrder = fieldIndex + 1
			fieldRow.Name = pathKey(field.path)
			fieldRow.Parent = sectionFrame
		end
	end

	return content
end

function MonitorOverlay:_logs(scope, snapshot)
	local content = scope:New("Frame")({
		Name = "Logs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})

	for reverseIndex = 1, 30 do
		scope:New("Frame")({
			Size = self:_computed(scope, snapshot, function(data)
				return data.logs[#data.logs - reverseIndex + 1] and UDim2.new(1, 0, 0, 54) or UDim2.new(1, 0, 0, 0)
			end),
			Visible = self:_computed(scope, snapshot, function(data)
				return data.logs[#data.logs - reverseIndex + 1] ~= nil
			end),
			BackgroundColor3 = COLORS.PanelRaised,
			BorderSizePixel = 0,
			Parent = content,
			[Fusion.Children] = {
				self:_corner(scope, UDim.new(0, 8)),
				self:_stroke(scope, COLORS.Stroke, 0.55),
				self:_padding(scope, 10, 7),
				self:_label(scope, {
					Size = UDim2.new(0, 62, 0, 18),
					Text = self:_computed(scope, snapshot, function(data)
						local entry = data.logs[#data.logs - reverseIndex + 1]
						return entry and entry.level or ""
					end),
					TextColor3 = self:_computed(scope, snapshot, function(data)
						local entry = data.logs[#data.logs - reverseIndex + 1]
						if entry and entry.level == "WARN" then
							return COLORS.Vermilion
						elseif entry and entry.level == "ACTION" then
							return COLORS.Jade
						end
						return COLORS.Amber
					end),
					FontFace = FONTS.Heading,
					TextSize = 10,
				}),
				self:_label(scope, {
					Position = UDim2.fromOffset(0, 19),
					Size = UDim2.new(1, 0, 0, 28),
					Text = self:_computed(scope, snapshot, function(data)
						local entry = data.logs[#data.logs - reverseIndex + 1]
						return entry and entry.message or ""
					end),
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = COLORS.TextMuted,
					TextSize = 11,
				}),
			},
		})
	end

	return content
end

function MonitorOverlay:mount()
	if self.gui then
		return
	end

	local scope = Fusion.scoped(Fusion)
	self.scope = scope
	local snapshot = scope:Value(self.controller:getSnapshot())
	local collapsed = scope:Value(false)
	local activeTab = scope:Value("Overview")
	local position = scope:Value(UDim2.new(1, -(Theme.PanelWidth + 24), 0, 72))
	local panelSizeGoal = scope:Computed(function(use)
		return use(collapsed)
			and UDim2.fromOffset(Theme.PanelWidth, Theme.HeaderHeight)
			or UDim2.fromOffset(Theme.PanelWidth, Theme.PanelHeight)
	end)
	local panelSize = scope:Tween(panelSizeGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))

	local dragging = false
	local dragStart = Vector2.zero
	local startOffset = Vector2.zero
	local panel

	local function clampPosition(offset)
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local height = Fusion.peek(collapsed) and Theme.HeaderHeight or Theme.PanelHeight
		return Vector2.new(
			math.clamp(offset.X, 8, math.max(8, viewport.X - Theme.PanelWidth - 8)),
			math.clamp(offset.Y, 8, math.max(8, viewport.Y - height - 8))
		)
	end

	table.insert(scope, UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local nextOffset = clampPosition(startOffset + input.Position - dragStart)
			position:set(UDim2.fromOffset(nextOffset.X, nextOffset.Y))
		end
	end))
	table.insert(scope, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	local gui = scope:New("ScreenGui")({
		Name = "SushiShopMonitor",
		DisplayOrder = 100000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self.refs.playerGui,
	})
	self.gui = gui

	panel = scope:New("Frame")({
		Name = "Panel",
		Position = position,
		Size = panelSize,
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
		[Fusion.Children] = {
			self:_corner(scope, UDim.new(0, 14)),
			self:_stroke(scope, COLORS.Stroke, 0.05),
		},
	})

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, Theme.HeaderHeight),
		BackgroundColor3 = COLORS.PanelRaised,
		BorderSizePixel = 0,
		Parent = panel,
		[Fusion.OnEvent("InputBegan")] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startOffset = Vector2.new(panel.AbsolutePosition.X, panel.AbsolutePosition.Y)
			end
		end,
		[Fusion.Children] = {
			self:_label(scope, {
				Position = UDim2.fromOffset(16, 9),
				Size = UDim2.new(1, -112, 0, 22),
				Text = "SUSHI SHOP CONTROL",
				TextSize = 14,
				FontFace = FONTS.Heading,
				TextColor3 = COLORS.Text,
			}),
			self:_label(scope, {
				Position = UDim2.fromOffset(16, 31),
				Size = UDim2.new(1, -112, 0, 17),
				Text = self:_computed(scope, snapshot, function(data)
					return data.paused and "Automation paused" or (data.telemetry.currentTask or "Monitoring")
				end),
				TextSize = 10,
				TextColor3 = self:_computed(scope, snapshot, function(data)
					return data.paused and COLORS.Amber or COLORS.Jade
				end),
			}),
		},
	})
	self:_button(scope, self:_computed(scope, collapsed, function(isCollapsed)
		return isCollapsed and "OPEN" or "HIDE"
	end), function()
		collapsed:set(not Fusion.peek(collapsed))
	end, {
		Position = UDim2.new(1, -86, 0, 13),
		Size = UDim2.fromOffset(70, 32),
		BackgroundColor3 = COLORS.JadeDark,
	}).Parent = header

	local tabBar = scope:New("Frame")({
		Position = UDim2.fromOffset(12, Theme.HeaderHeight + 10),
		Size = UDim2.new(1, -24, 0, 38),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return not use(collapsed)
		end),
		Parent = panel,
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellPadding = UDim2.fromOffset(6, 0),
				CellSize = UDim2.new(0.25, -5, 1, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	for index, tabName in TABS do
		self:_button(scope, tabName, function()
			activeTab:set(tabName)
		end, {
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = scope:Computed(function(use)
				return use(activeTab) == tabName and COLORS.JadeDark or COLORS.PanelSoft
			end),
			TextColor3 = scope:Computed(function(use)
				return use(activeTab) == tabName and COLORS.Text or COLORS.TextMuted
			end),
		}).Parent = tabBar
	end

	local contentHost = scope:New("Frame")({
		Position = UDim2.fromOffset(12, Theme.HeaderHeight + 58),
		Size = UDim2.new(1, -24, 1, -(Theme.HeaderHeight + 70)),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return not use(collapsed)
		end),
		Parent = panel,
	})

	local pages = {
		Overview = self:_overview(scope, snapshot),
		Stock = self:_stock(scope, snapshot),
		Settings = self:_settings(scope, snapshot),
		Logs = self:_logs(scope, snapshot),
	}
	for tabName, page in pages do
		scope:New("ScrollingFrame")({
			Name = `{tabName}Page`,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = COLORS.JadeDark,
			Visible = scope:Computed(function(use)
				return use(activeTab) == tabName
			end),
			Parent = contentHost,
			[Fusion.Children] = {
				page,
				self:_padding(scope, 0, 2),
			},
		})
	end

	self.unsubscribe = self.controller:subscribe(function()
		if self.scope then
			snapshot:set(self.controller:getSnapshot())
		end
	end)
end

function MonitorOverlay:destroy()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
	if self.scope then
		local scope = self.scope
		self.scope = nil
		Fusion.doCleanup(scope)
	end
	self.gui = nil
end

return MonitorOverlay
