local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Runtime = require("./react-runtime")
local Theme = require("./monitor-theme")
local Schema = require("./monitor-schema")

local React = Runtime.React
local e = Runtime.createElement
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local function corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or Theme.CornerRadius),
	})
end

local function stroke(color, transparency)
	return e("UIStroke", {
		Color = color or Colors.Stroke,
		Transparency = transparency or 0,
		Thickness = 1,
	})
end

local function padding(amount)
	return e("UIPadding", {
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
	})
end

local function listLayout(direction, spacing, alignment)
	return e("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, spacing or Theme.Spacing),
	})
end

local function Text(props)
	return e("TextLabel", {
		AutomaticSize = props.automaticSize or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Font = props.font or Fonts.Body,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size or UDim2.fromScale(1, 1),
		Text = tostring(props.text or ""),
		TextColor3 = props.color or Colors.Text,
		TextSize = props.textSize or 13,
		TextTruncate = props.truncate,
		TextWrapped = props.wrapped or false,
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
	})
end

local function Button(props)
	local background = props.background or Colors.PanelSoft
	return e("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = background,
		Font = props.font or Fonts.Medium,
		LayoutOrder = props.layoutOrder,
		Size = props.size or UDim2.fromOffset(104, 32),
		Text = props.text,
		TextColor3 = props.textColor or Colors.Text,
		TextSize = props.textSize or 12,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = corner(7),
		Stroke = stroke(props.strokeColor or background:Lerp(Colors.Text, 0.18), 0.35),
	})
end

local function StatusChip(props)
	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = props.color,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = corner(99),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
		}),
		Label = Text({
			automaticSize = Enum.AutomaticSize.XY,
			text = props.text,
			textSize = 11,
			font = Fonts.Bold,
		}),
	})
end

local function Card(props)
	local children = {
		Corner = corner(9),
		Stroke = stroke(Colors.Stroke, 0.38),
		Padding = padding(12),
		Layout = listLayout(Enum.FillDirection.Vertical, 7),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		AutomaticSize = props.automaticSize or Enum.AutomaticSize.Y,
		BackgroundColor3 = props.background or Colors.PanelRaised,
		LayoutOrder = props.layoutOrder,
		Size = props.size or UDim2.new(1, 0, 0, 0),
	}, children)
end

local function StatRow(props)
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 22),
	}, {
		Label = Text({
			size = UDim2.new(0.56, 0, 1, 0),
			text = props.label,
			color = Colors.TextMuted,
			textSize = 12,
		}),
		Value = Text({
			position = UDim2.fromScale(0.56, 0),
			size = UDim2.new(0.44, 0, 1, 0),
			text = props.value,
			font = Fonts.Medium,
			textSize = 12,
			xAlignment = Enum.TextXAlignment.Right,
			color = props.color,
			truncate = Enum.TextTruncate.AtEnd,
		}),
	})
end

local function SectionTitle(props)
	return Text({
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
		size = UDim2.new(1, 0, 0, 0),
		text = props.text,
		font = Fonts.Bold,
		textSize = 13,
	})
end

local function ScrollPage(props)
	local children = {
		Padding = padding(12),
		Layout = listLayout(Enum.FillDirection.Vertical, 10),
	}
	for key, child in props.children or {} do
		children[key] = child
	end

	return e("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Colors.Jade,
		ScrollBarThickness = 4,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

local function formatClock(clockTime)
	if not clockTime then
		return "Unknown"
	end
	local hour = math.floor(clockTime)
	local minute = math.floor((clockTime - hour) * 60 + 0.5)
	local meridiem = hour >= 12 and "PM" or "AM"
	local displayHour = hour % 12
	if displayHour == 0 then
		displayHour = 12
	end
	return string.format("%d:%02d %s", displayHour, minute, meridiem)
end

local function OverviewTab(props)
	local snapshot = props.snapshot
	local telemetry = snapshot.telemetry
	local actionChildren = {
		Layout = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(8, 8),
			CellSize = UDim2.new(0.5, -4, 0, 32),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Pause = Button({
			layoutOrder = 1,
			text = snapshot.paused and "Resume" or "Pause",
			background = snapshot.paused and Colors.JadeDark or Colors.Vermilion,
			onActivated = props.controller.togglePaused and function()
				props.controller:togglePaused()
			end,
		}),
		Wake = Button({
			layoutOrder = 2,
			text = "Wake",
			onActivated = function()
				props.controller:wakeNow()
			end,
		}),
		Refresh = Button({
			layoutOrder = 3,
			text = "Refresh World",
			onActivated = function()
				props.controller:refreshWorld()
			end,
		}),
		Tips = Button({
			layoutOrder = 4,
			text = "Claim Tips",
			onActivated = function()
				props.controller:claimTipsNow()
			end,
		}),
	}

	return ScrollPage({
		children = {
			Status = Card({
				layoutOrder = 1,
				children = {
					Title = SectionTitle({ layoutOrder = 1, text = "Live Status" }),
					Current = StatRow({
						layoutOrder = 2,
						label = "Current task",
						value = telemetry.currentTask,
						color = snapshot.paused and Colors.Amber or Colors.Jade,
					}),
					Decision = StatRow({
						layoutOrder = 3,
						label = "Last decision",
						value = telemetry.lastDecision,
					}),
					Action = StatRow({
						layoutOrder = 4,
						label = "Last action",
						value = telemetry.lastAction or "None",
					}),
					Movement = StatRow({
						layoutOrder = 5,
						label = "Movement target",
						value = telemetry.lastMovementTarget or "Idle",
					}),
				},
			}),
			Metrics = Card({
				layoutOrder = 2,
				children = {
					Title = SectionTitle({ layoutOrder = 1, text = "Shop Snapshot" }),
					Time = StatRow({
						layoutOrder = 2,
						label = "Time / day",
						value = `{formatClock(snapshot.clockTime)} / {snapshot.day}`,
					}),
					Energy = StatRow({
						layoutOrder = 3,
						label = "Energy / level",
						value = `{snapshot.energy} / {snapshot.level}`,
						color = snapshot.energy <= 10 and Colors.Red or Colors.Text,
					}),
					Funds = StatRow({
						layoutOrder = 4,
						label = "Bank / sales / wallet",
						value = `{snapshot.bank} / {snapshot.sales} / {snapshot.wallet}`,
					}),
					Plates = StatRow({
						layoutOrder = 5,
						label = "Clean / dirty plates",
						value = `{snapshot.plates} / {snapshot.dirtyPlates}`,
					}),
					Recipe = StatRow({
						layoutOrder = 6,
						label = "Recipe",
						value = snapshot.currentRecipe,
					}),
					Best = StatRow({
						layoutOrder = 7,
						label = "Best craftable",
						value = snapshot.bestRecipe,
						color = Colors.Jade,
					}),
					Tips = StatRow({
						layoutOrder = 8,
						label = "Tips available",
						value = snapshot.tips,
					}),
				},
			}),
			Stations = Card({
				layoutOrder = 3,
				children = {
					Title = SectionTitle({ layoutOrder = 1, text = "World Availability" }),
					Cook = StatRow({
						layoutOrder = 2,
						label = "Cook stations",
						value = `{snapshot.cookStations.available} / {snapshot.cookStations.total}`,
					}),
					Sinks = StatRow({
						layoutOrder = 3,
						label = "Sinks",
						value = `{snapshot.sinks.available} / {snapshot.sinks.total}`,
					}),
					Sofas = StatRow({
						layoutOrder = 4,
						label = "Sofa seats",
						value = `{snapshot.sofaSeats.available} / {snapshot.sofaSeats.total}`,
					}),
				},
			}),
			Actions = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 72),
			}, actionChildren),
		},
	})
end

local function StockTab(props)
	local snapshot = props.snapshot
	local children = {}
	for index, item in snapshot.stock do
		local low = item.value < item.threshold
		children[`Stock{item.name}`] = Card({
			layoutOrder = index,
			background = low and Colors.PanelSoft:Lerp(Colors.Red, 0.12) or Colors.PanelRaised,
			children = {
				Name = SectionTitle({
					layoutOrder = 1,
					text = item.name,
				}),
				Value = StatRow({
					layoutOrder = 2,
					label = "Current / threshold",
					value = `{item.value} / {item.threshold}`,
					color = low and Colors.Red or Colors.Jade,
				}),
				Price = StatRow({
					layoutOrder = 3,
					label = "Unit price",
					value = item.price or "Unknown",
				}),
			},
		})
	end

	local restock = snapshot.restock
	children.Restock = Card({
		layoutOrder = 100,
		background = Colors.PanelSoft,
		children = {
			Title = SectionTitle({ layoutOrder = 1, text = "Next Restock" }),
			Item = StatRow({
				layoutOrder = 2,
				label = "Candidate",
				value = restock and restock.name or "Stock levels healthy",
			}),
			Cost = StatRow({
				layoutOrder = 3,
				label = "Cost / source",
				value = restock
					and `{restock.cost} / {restock.paymentSource or "insufficient funds"}`
					or "-",
				color = restock and restock.actionable and Colors.Jade or Colors.Amber,
			}),
		},
	})

	return ScrollPage({ children = children })
end

local function SettingField(props)
	local value = props.controller:getSetting(props.path)
	local field = props.field
	local draft, setDraft = React.useState(tostring(value))
	local problem, setProblem = React.useState(nil)

	React.useEffect(function()
		setDraft(tostring(value))
	end, { value })

	local function commit(rawValue)
		local success, message = props.controller:setSetting(props.path, rawValue)
		if success then
			setProblem(nil)
			setDraft(tostring(props.controller:getSetting(props.path)))
		else
			setProblem(message)
			setDraft(tostring(props.controller:getSetting(props.path)))
		end
	end

	local editor
	if field.kind == "boolean" then
		editor = Button({
			text = value and "On" or "Off",
			size = UDim2.fromOffset(78, 30),
			background = value and Colors.JadeDark or Colors.PanelSoft,
			onActivated = function()
				commit(not value)
			end,
		})
	else
		editor = e("TextBox", {
			BackgroundColor3 = Colors.Backdrop,
			ClearTextOnFocus = false,
			Font = Fonts.Mono,
			Size = UDim2.fromOffset(190, 30),
			Text = draft,
			TextColor3 = Colors.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Change.Text] = function(rbx)
				setDraft(rbx.Text)
			end,
			[React.Event.FocusLost] = function(rbx)
				commit(rbx.Text)
			end,
		}, {
			Corner = corner(6),
			Stroke = stroke(problem and Colors.Red or Colors.Stroke, 0.25),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, problem and 52 or 34),
	}, {
		Row = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
		}, {
			Label = Text({
				size = UDim2.new(1, -202, 1, 0),
				text = field.label,
				color = Colors.TextMuted,
				textSize = 12,
			}),
			Editor = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(190, 30),
			}, {
				Control = editor,
			}),
		}),
		Error = problem and Text({
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromOffset(0, 32),
			size = UDim2.new(1, 0, 0, 0),
			text = problem,
			color = Colors.Red,
			textSize = 11,
			wrapped = true,
		}) or nil,
	})
end

local function SettingsTab(props)
	local children = {}
	for sectionIndex, section in Schema.sections do
		local sectionChildren = {
			Title = SectionTitle({ layoutOrder = 1, text = section.label }),
		}
		for fieldIndex, field in Schema.getFields(section, props.controller.settings) do
			sectionChildren[`Field{field.key}`] = e(SettingField, {
				controller = props.controller,
				field = field,
				layoutOrder = fieldIndex + 1,
				path = `{section.key}.{field.key}`,
			})
		end
		sectionChildren.Reset = Button({
			layoutOrder = 100,
			text = "Reset Section",
			size = UDim2.fromOffset(112, 30),
			onActivated = function()
				props.controller:resetSection(section.key)
			end,
		})
		children[`Section{section.key}`] = Card({
			layoutOrder = sectionIndex,
			children = sectionChildren,
		})
	end

	children.ResetAll = Button({
		layoutOrder = 1000,
		text = "Reset All Settings",
		size = UDim2.fromOffset(150, 32),
		background = Colors.Vermilion,
		onActivated = function()
			props.controller:resetAll()
		end,
	})

	return ScrollPage({ children = children })
end

local function LogsTab(props)
	local children = {}
	for index = #props.logs, 1, -1 do
		local entry = props.logs[index]
		local levelColor = if entry.level == "WARN"
			then Colors.Red
			elseif entry.level == "ACTION" then Colors.Jade
			elseif entry.level == "DEBUG" then Colors.TextMuted
			else Colors.Amber
		children[`Log{index}`] = Card({
			layoutOrder = #props.logs - index + 1,
			children = {
				Level = Text({
					automaticSize = Enum.AutomaticSize.Y,
					layoutOrder = 1,
					size = UDim2.new(1, 0, 0, 0),
					text = entry.level,
					font = Fonts.Bold,
					textSize = 10,
					color = levelColor,
				}),
				Message = Text({
					automaticSize = Enum.AutomaticSize.Y,
					layoutOrder = 2,
					size = UDim2.new(1, 0, 0, 0),
					text = entry.message,
					textSize = 12,
					wrapped = true,
				}),
			},
		})
	end
	if #props.logs == 0 then
		children.Empty = Text({
			automaticSize = Enum.AutomaticSize.Y,
			layoutOrder = 1,
			size = UDim2.new(1, 0, 0, 0),
			text = "No events recorded yet.",
			color = Colors.TextMuted,
			textSize = 13,
		})
	end
	return ScrollPage({ children = children })
end

local TABS = { "Overview", "Stock", "Settings", "Logs" }

local function Header(props)
	local statusColor = if props.snapshot.gameover
		then Colors.Red
		elseif props.snapshot.paused then Colors.Amber
		elseif props.snapshot.busy then Colors.Jade
		else Colors.JadeDark
	local statusText = if props.snapshot.gameover
		then "GAME OVER"
		elseif props.snapshot.paused then "PAUSED"
		elseif props.snapshot.busy then "WORKING"
		else "READY"

	return e("Frame", {
		Active = true,
		BackgroundColor3 = Colors.PanelRaised,
		Size = UDim2.new(1, 0, 0, Theme.HeaderHeight),
		[React.Event.InputBegan] = props.onInputBegan,
	}, {
		Corner = corner(Theme.CornerRadius),
		Title = Text({
			position = UDim2.fromOffset(16, 8),
			size = UDim2.new(1, -190, 0, 23),
			text = "SUSHI SHOP OPS",
			font = Fonts.Bold,
			textSize = 15,
		}),
		Subtitle = Text({
			position = UDim2.fromOffset(16, 31),
			size = UDim2.new(1, -190, 0, 18),
			text = props.snapshot.shopOpen and "Shop open" or "Shop closed",
			color = Colors.TextMuted,
			textSize = 11,
		}),
		Status = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -158, 0, 15),
		}, {
			Chip = e(StatusChip, {
				color = statusColor,
				text = statusText,
			}),
		}),
		Collapse = e("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			AutoButtonColor = true,
			BackgroundColor3 = Colors.PanelSoft,
			Font = Fonts.Bold,
			Position = UDim2.new(1, -12, 0, 13),
			Size = UDim2.fromOffset(32, 32),
			Text = props.collapsed and "+" or "-",
			TextColor3 = Colors.Text,
			TextSize = 18,
			[React.Event.Activated] = props.onToggleCollapsed,
		}, {
			Corner = corner(7),
		}),
	})
end

local function TabBar(props)
	local children = {
		Layout = listLayout(Enum.FillDirection.Horizontal, 6),
	}
	for index, tab in TABS do
		local selected = props.activeTab == tab
		children[tab] = Button({
			layoutOrder = index,
			text = tab,
			size = UDim2.new(0.25, -5, 1, 0),
			background = selected and Colors.JadeDark or Colors.PanelRaised,
			textColor = selected and Colors.Text or Colors.TextMuted,
			onActivated = function()
				props.setActiveTab(tab)
			end,
		})
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, Theme.HeaderHeight + 10),
		Size = UDim2.new(1, -24, 0, 34),
	}, children)
end

local function clampPosition(position, collapsed, panelWidth, panelHeight, viewport)
	local height = collapsed and Theme.HeaderHeight or panelHeight
	return Vector2.new(
		math.clamp(position.X, 8, math.max(8, viewport.X - panelWidth - 8)),
		math.clamp(position.Y, 8, math.max(8, viewport.Y - height - 8))
	)
end

local function MonitorApp(props)
	local initialViewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
		or Vector2.new(1280, 720)
	local viewport, setViewport = React.useState(initialViewport)
	local panelWidth = math.max(304, math.min(Theme.PanelWidth, viewport.X - 16))
	local panelHeight = math.max(400, math.min(Theme.ExpandedHeight, viewport.Y - 16))
	local snapshot, setSnapshot = React.useState(props.controller:getSnapshot())
	local logs, setLogs = React.useState(props.controller:getLogs())
	local activeTab, setActiveTab = React.useState("Overview")
	local collapsed, setCollapsed = React.useState(false)
	local position, setPosition = React.useState(Vector2.new(
		math.max(8, initialViewport.X - panelWidth - 24),
		28
	))
	local dragState = React.useRef(nil)

	React.useEffect(function()
		local function refresh()
			setSnapshot(props.controller:getSnapshot())
		end
		local disconnectState = props.controller:subscribe(refresh)
		local disconnectLog = props.controller:subscribeLog(function()
			setLogs(props.controller:getLogs())
			refresh()
		end)
		refresh()
		return function()
			disconnectState()
			disconnectLog()
		end
	end, { props.controller })

	React.useEffect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return nil
		end

		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewport(camera.ViewportSize)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		setPosition(function(current)
			return clampPosition(current, collapsed, panelWidth, panelHeight, viewport)
		end)
	end, { viewport, collapsed, panelWidth, panelHeight })

	React.useEffect(function()
		local changed = UserInputService.InputChanged:Connect(function(input)
			local drag = dragState.current
			if
				drag
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local delta = input.Position - drag.inputPosition
				setPosition(clampPosition(
					drag.panelPosition + Vector2.new(delta.X, delta.Y),
					collapsed,
					panelWidth,
					panelHeight,
					viewport
				))
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragState.current = nil
			end
		end)
		return function()
			changed:Disconnect()
			ended:Disconnect()
		end
	end, { collapsed, panelWidth, panelHeight, viewport })

	local function beginDrag(_, input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragState.current = {
				inputPosition = input.Position,
				panelPosition = position,
			}
		end
	end

	local page
	if activeTab == "Stock" then
		page = e(StockTab, { snapshot = snapshot })
	elseif activeTab == "Settings" then
		page = e(SettingsTab, { controller = props.controller })
	elseif activeTab == "Logs" then
		page = e(LogsTab, { logs = logs })
	else
		page = e(OverviewTab, {
			controller = props.controller,
			snapshot = snapshot,
		})
	end

	return e("ScreenGui", {
		DisplayOrder = 10000,
		IgnoreGuiInset = true,
		Name = "SushiShopMonitor",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Panel = e("Frame", {
			BackgroundColor3 = Colors.Panel,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(position.X, position.Y),
			Size = UDim2.fromOffset(
				panelWidth,
				collapsed and Theme.HeaderHeight or panelHeight
			),
		}, {
			Corner = corner(Theme.CornerRadius),
			Stroke = stroke(Colors.Stroke, 0.12),
			Header = e(Header, {
				collapsed = collapsed,
				onInputBegan = beginDrag,
				onToggleCollapsed = function()
					local nextCollapsed = not collapsed
					setCollapsed(nextCollapsed)
					setPosition(clampPosition(
						position,
						nextCollapsed,
						panelWidth,
						panelHeight,
						viewport
					))
				end,
				snapshot = snapshot,
			}),
			Tabs = not collapsed and e(TabBar, {
				activeTab = activeTab,
				setActiveTab = setActiveTab,
			}) or nil,
			Content = not collapsed and e("Frame", {
				BackgroundColor3 = Colors.Backdrop,
				Position = UDim2.fromOffset(12, Theme.HeaderHeight + 54),
				Size = UDim2.new(1, -24, 1, -(Theme.HeaderHeight + 66)),
			}, {
				Corner = corner(8),
				Page = page,
			}) or nil,
		}),
	})
end

return MonitorApp
