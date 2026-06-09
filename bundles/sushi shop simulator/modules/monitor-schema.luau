local MonitorSchema = {}

local sections = {
	{
		key = "Hours",
		title = "Shop Hours",
		fields = {
			{ path = "Hours.Open", label = "Opening Hour", kind = "number", minimum = 0, maximum = 23.99 },
			{ path = "Hours.Close", label = "Closing Hour", kind = "number", minimum = 0, maximum = 24 },
			{ path = "Hours.Midnight", label = "Midnight Hour", kind = "number", minimum = 0, maximum = 23.99 },
		},
	},
	{
		key = "Recipes",
		title = "Recipes",
		fields = {
			{ path = "Recipes.Count", label = "Recipe Count", kind = "number", minimum = 1, maximum = 200, integer = true },
			{ path = "Recipes.MinimumCookSeconds", label = "Minimum Cook Seconds", kind = "number", minimum = 0.01, maximum = 60 },
			{
				path = "Recipes.Priority",
				label = "Recipe Priority",
				kind = "dropdown",
				options = { "business_profit", "commission", "xp" },
			},
		},
	},
	{
		key = "StockThresholds",
		title = "Stock Thresholds",
		fields = {
			{ path = "StockThresholds.Rice", label = "Rice", kind = "number", minimum = 0, integer = true },
			{ path = "StockThresholds.Vegetable", label = "Vegetable", kind = "number", minimum = 0, integer = true },
			{ path = "StockThresholds.Fish", label = "Fish", kind = "number", minimum = 0, integer = true },
			{ path = "StockThresholds.SoyaSauce", label = "Soya Sauce", kind = "number", minimum = 0, integer = true },
			{ path = "StockThresholds.PremFish", label = "Premium Fish", kind = "number", minimum = 0, integer = true },
		},
	},
	{
		key = "RestockCodes",
		title = "Restock Multipliers",
		fields = {
			{ path = "RestockCodes.Vegetable.CostMultiplier", label = "Vegetable", kind = "number", minimum = 1 },
			{ path = "RestockCodes.Rice.CostMultiplier", label = "Rice", kind = "number", minimum = 1 },
			{ path = "RestockCodes.Fish.CostMultiplier", label = "Fish", kind = "number", minimum = 1 },
			{ path = "RestockCodes.SoyaSauce.CostMultiplier", label = "Soya Sauce", kind = "number", minimum = 1 },
			{ path = "RestockCodes.Coffee.CostMultiplier", label = "Coffee", kind = "number", minimum = 1 },
			{ path = "RestockCodes.PremFish.CostMultiplier", label = "Premium Fish", kind = "number", minimum = 1 },
		},
	},
	{
		key = "Movement",
		title = "Movement",
		fields = {
			{ path = "Movement.AgentRadius", label = "Agent Radius", kind = "number", minimum = 0.5, maximum = 20 },
			{ path = "Movement.AgentHeight", label = "Agent Height", kind = "number", minimum = 1, maximum = 30 },
			{ path = "Movement.AgentCanJump", label = "Agent Can Jump", kind = "boolean" },
			{ path = "Movement.AgentCanClimb", label = "Agent Can Climb", kind = "boolean" },
			{ path = "Movement.DefaultWalkSpeed", label = "Default Walk Speed", kind = "number", minimum = 0, maximum = 200 },
			{ path = "Movement.WaypointSpacing", label = "Waypoint Spacing", kind = "number", minimum = 1, maximum = 100 },
			{ path = "Movement.ArrivalRadius", label = "Arrival Radius", kind = "number", minimum = 0.5, maximum = 50 },
			{ path = "Movement.SeatRadius", label = "Seat Radius", kind = "number", minimum = 0.5, maximum = 50 },
			{ path = "Movement.WaypointTimeout", label = "Waypoint Timeout", kind = "number", minimum = 0.1, maximum = 120 },
			{ path = "Movement.RepathRetries", label = "Repath Retries", kind = "number", minimum = 0, maximum = 20, integer = true },
			{ path = "Movement.PollInterval", label = "Poll Interval", kind = "number", minimum = 0.01, maximum = 5 },
			{ path = "Movement.UnsitTimeout", label = "Unsit Timeout", kind = "number", minimum = 0.1, maximum = 30 },
		},
	},
	{
		key = "Occupancy",
		title = "Station Occupancy",
		fields = {
			{ path = "Occupancy.StandHereRadius", label = "Stand Here Radius", kind = "number", minimum = 0.5, maximum = 50 },
			{ path = "Occupancy.VacancyCooldown", label = "Vacancy Cooldown", kind = "number", minimum = 0, maximum = 60 },
			{ path = "Occupancy.RefreshInterval", label = "Refresh Interval", kind = "number", minimum = 0.01, maximum = 10 },
		},
	},
	{
		key = "Timing",
		title = "Timing",
		fields = {
			{ path = "Timing.ActionStartTimeout", label = "Action Start Timeout", kind = "number", minimum = 0.1, maximum = 60 },
			{ path = "Timing.InteractionDebounce", label = "Interaction Debounce", kind = "number", minimum = 0, maximum = 10 },
			{ path = "Timing.ActionRetry", label = "Action Retry", kind = "number", minimum = 0, maximum = 60 },
			{ path = "Timing.CookBuffer", label = "Cook Buffer", kind = "number", minimum = 0, maximum = 60 },
			{ path = "Timing.WashTimeout", label = "Wash Timeout", kind = "number", minimum = 0.1, maximum = 120 },
			{ path = "Timing.PurchaseTimeout", label = "Purchase Timeout", kind = "number", minimum = 0.1, maximum = 120 },
			{ path = "Timing.RecipeSwitchCooldown", label = "Recipe Switch Cooldown", kind = "number", minimum = 0, maximum = 120 },
			{ path = "Timing.ModalCloseDelay", label = "Modal Close Delay", kind = "number", minimum = 0, maximum = 30 },
			{ path = "Timing.TargetBlacklist", label = "Target Blacklist", kind = "number", minimum = 0, maximum = 120 },
			{ path = "Timing.NightRestRecheck", label = "Night Rest Recheck", kind = "number", minimum = 0.01, maximum = 10 },
			{ path = "Timing.TipJarDebounce", label = "Tip Jar Debounce", kind = "number", minimum = 0, maximum = 60 },
			{ path = "Timing.IdleRetry", label = "Idle Retry", kind = "number", minimum = 0.01, maximum = 60 },
		},
	},
	{
		key = "Energy",
		title = "Energy",
		fields = {
			{ path = "Energy.Minimum", label = "Rest At", kind = "number", minimum = 0, maximum = 1000 },
			{ path = "Energy.Resume", label = "Resume At", kind = "number", minimum = 0, maximum = 1000 },
		},
	},
	{
		key = "Logging",
		title = "Logging",
		fields = {
			{ path = "Logging.Enabled", label = "Console Logging", kind = "boolean" },
			{ path = "Logging.Verbose", label = "Verbose Logging", kind = "boolean" },
			{ path = "Logging.Prefix", label = "Log Prefix", kind = "string" },
		},
	},
}

local fieldsByPath = {}
for _, section in sections do
	for _, field in section.fields do
		field.sectionKey = section.key
		fieldsByPath[field.path] = field
	end
end

function MonitorSchema.getSections()
	return sections
end

function MonitorSchema.getSection(sectionKey)
	for _, section in sections do
		if section.key == sectionKey then
			return section
		end
	end
	return nil
end

function MonitorSchema.getField(path)
	return fieldsByPath[path]
end

function MonitorSchema.validate(path, rawValue)
	local field = fieldsByPath[path]
	if not field then
		return false, nil, `Unknown setting: {path}`
	end

	if field.kind == "boolean" then
		if typeof(rawValue) ~= "boolean" then
			return false, nil, `{field.label} must be true or false`
		end
		return true, rawValue
	end

	if field.kind == "string" then
		local value = tostring(rawValue)
		if value == "" then
			return false, nil, `{field.label} cannot be empty`
		end
		return true, value
	end

	if field.kind == "dropdown" then
		local value = typeof(rawValue) == "table" and rawValue[1] or rawValue
		if table.find(field.options, value) == nil then
			return false, nil, `{field.label} has an unsupported value`
		end
		return true, value
	end

	local value = tonumber(rawValue)
	if value == nil then
		return false, nil, `{field.label} must be a number`
	end
	if field.integer and value % 1 ~= 0 then
		return false, nil, `{field.label} must be a whole number`
	end
	if field.minimum ~= nil and value < field.minimum then
		return false, nil, `{field.label} must be at least {field.minimum}`
	end
	if field.maximum ~= nil and value > field.maximum then
		return false, nil, `{field.label} must be at most {field.maximum}`
	end

	return true, value
end

return MonitorSchema
