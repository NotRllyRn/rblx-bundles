local function numberField(path, label, minimum, maximum, step)
	return {
		path = path,
		label = label,
		kind = "number",
		minimum = minimum,
		maximum = maximum,
		step = step,
	}
end

return {
	{
		key = "Hours",
		label = "Shop Hours",
		fields = {
			numberField({ "Hours", "Open" }, "Opening hour", 0, 23, 1),
			numberField({ "Hours", "Close" }, "Closing hour", 0, 24, 1),
		},
	},
	{
		key = "Recipes",
		label = "Recipe Strategy",
		fields = {
			{
				path = { "Recipes", "Priority" },
				label = "Priority",
				kind = "choice",
				choices = { "business_profit", "commission", "xp" },
			},
			numberField({ "Recipes", "Count" }, "Recipe count", 1, 100, 1),
			numberField({ "Recipes", "MinimumCookSeconds" }, "Minimum cook seconds", 0.01, 60, 0.01),
		},
	},
	{
		key = "StockThresholds",
		label = "Restock Thresholds",
		fields = {
			numberField({ "StockThresholds", "Rice" }, "Rice", 0, 100000, 1),
			numberField({ "StockThresholds", "Vegetable" }, "Vegetable", 0, 100000, 1),
			numberField({ "StockThresholds", "Fish" }, "Fish", 0, 100000, 1),
			numberField({ "StockThresholds", "SoyaSauce" }, "Soya sauce", 0, 100000, 1),
			numberField({ "StockThresholds", "PremFish" }, "Premium fish", 0, 100000, 1),
		},
	},
	{
		key = "RestockCodes",
		label = "Restock Multipliers",
		fields = {
			numberField({ "RestockCodes", "Rice", "CostMultiplier" }, "Rice", 1, 10000, 1),
			numberField({ "RestockCodes", "Vegetable", "CostMultiplier" }, "Vegetable", 1, 10000, 1),
			numberField({ "RestockCodes", "Fish", "CostMultiplier" }, "Fish", 1, 10000, 1),
			numberField({ "RestockCodes", "SoyaSauce", "CostMultiplier" }, "Soya sauce", 1, 10000, 1),
			numberField({ "RestockCodes", "Coffee", "CostMultiplier" }, "Coffee", 1, 10000, 1),
			numberField({ "RestockCodes", "PremFish", "CostMultiplier" }, "Premium fish", 1, 10000, 1),
		},
	},
	{
		key = "Energy",
		label = "Energy",
		fields = {
			numberField({ "Energy", "Minimum" }, "Rest below", 0, 1000, 1),
			numberField({ "Energy", "Resume" }, "Resume above", 0, 1000, 1),
		},
	},
	{
		key = "Movement",
		label = "Movement",
		fields = {
			numberField({ "Movement", "AgentRadius" }, "Agent radius", 0.5, 10, 0.1),
			numberField({ "Movement", "AgentHeight" }, "Agent height", 1, 20, 0.1),
			{ path = { "Movement", "AgentCanJump" }, label = "Can jump", kind = "boolean" },
			{ path = { "Movement", "AgentCanClimb" }, label = "Can climb", kind = "boolean" },
			numberField({ "Movement", "DefaultWalkSpeed" }, "Default walk speed", 1, 100, 1),
			numberField({ "Movement", "WaypointSpacing" }, "Waypoint spacing", 1, 20, 0.5),
			numberField({ "Movement", "ArrivalRadius" }, "Arrival radius", 0.5, 20, 0.1),
			numberField({ "Movement", "SeatRadius" }, "Seat radius", 0.5, 20, 0.1),
			numberField({ "Movement", "WaypointTimeout" }, "Waypoint timeout", 0.5, 60, 0.5),
			numberField({ "Movement", "RepathRetries" }, "Repath retries", 1, 20, 1),
			numberField({ "Movement", "PollInterval" }, "Poll interval", 0.01, 5, 0.01),
			numberField({ "Movement", "UnsitTimeout" }, "Unsit timeout", 0.1, 20, 0.1),
		},
	},
	{
		key = "Occupancy",
		label = "Station Occupancy",
		fields = {
			numberField({ "Occupancy", "StandHereRadius" }, "Detection radius", 0.5, 20, 0.1),
			numberField({ "Occupancy", "VacancyCooldown" }, "Vacancy cooldown", 0, 60, 0.1),
			numberField({ "Occupancy", "RefreshInterval" }, "Refresh interval", 0.01, 10, 0.01),
		},
	},
	{
		key = "Timing",
		label = "Timing",
		fields = {
			numberField({ "Timing", "ActionStartTimeout" }, "Action start timeout", 0.1, 60, 0.1),
			numberField({ "Timing", "InteractionDebounce" }, "Interaction debounce", 0, 10, 0.01),
			numberField({ "Timing", "ActionRetry" }, "Action retry", 0, 60, 0.1),
			numberField({ "Timing", "CookBuffer" }, "Cook buffer", 0, 60, 0.1),
			numberField({ "Timing", "WashTimeout" }, "Wash timeout", 0.1, 120, 0.1),
			numberField({ "Timing", "PurchaseTimeout" }, "Purchase timeout", 0.1, 120, 0.1),
			numberField({ "Timing", "RecipeSwitchCooldown" }, "Recipe switch cooldown", 0, 60, 0.1),
			numberField({ "Timing", "ModalCloseDelay" }, "Modal close delay", 0, 30, 0.1),
			numberField({ "Timing", "TargetBlacklist" }, "Target blacklist", 0, 60, 0.1),
			numberField({ "Timing", "NightRestRecheck" }, "Rest recheck", 0.01, 10, 0.01),
			numberField({ "Timing", "TipJarDebounce" }, "Tip debounce", 0, 60, 0.1),
			numberField({ "Timing", "IdleRetry" }, "Idle retry", 0.01, 60, 0.01),
		},
	},
	{
		key = "Logging",
		label = "Logging",
		fields = {
			{ path = { "Logging", "Enabled" }, label = "Enabled", kind = "boolean" },
			{ path = { "Logging", "Verbose" }, label = "Verbose", kind = "boolean" },
		},
	},
}
