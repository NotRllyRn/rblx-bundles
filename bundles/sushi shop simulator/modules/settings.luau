local settings = {
	Hours = {
		Open = 10,
		Close = 23,
		Midnight = 0,
	},

	Recipes = {
		Count = 20,
		MinimumCookSeconds = 0.1,
		Priority = "business_profit",
	},

	StockThresholds = {
		Rice = 100,
		Vegetable = 100,
		Fish = 100,
		SoyaSauce = 100,
		PremFish = 10,
	},

	RestockCodes = {
		Vegetable = { Wallet = 1, Business = 2, CostMultiplier = 100 },
		Rice = { Wallet = 3, Business = 4, CostMultiplier = 100 },
		Fish = { Wallet = 5, Business = 6, CostMultiplier = 100 },
		SoyaSauce = { Wallet = 9, Business = 10, CostMultiplier = 100 },
		Coffee = { Wallet = 11, Business = 12, CostMultiplier = 10 },
		PremFish = { Wallet = 13, Business = 14, CostMultiplier = 10 },
	},

	Movement = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		DefaultWalkSpeed = 16,
		WaypointSpacing = 4,
		ArrivalRadius = 3.5,
		SeatRadius = 2.5,
		WaypointTimeout = 8,
		RepathRetries = 3,
		PollInterval = 0.05,
		UnsitTimeout = 1,
	},

	Occupancy = {
		StandHereRadius = 3,
		VacancyCooldown = 5,
		RefreshInterval = 0.2,
	},

	Timing = {
		ActionStartTimeout = 2,
		InteractionDebounce = 0.1,
		ActionRetry = 1,
		CookBuffer = 1.5,
		WashTimeout = 6,
		PurchaseTimeout = 5,
		RecipeSwitchCooldown = 3,
		ModalCloseDelay = 1,
		TargetBlacklist = 3,
		NightRestRecheck = 0.5,
		TipJarDebounce = 2,
		IdleRetry = 1,
	},

	Energy = {
		Minimum = 5,
		Resume = 195,
	},

	Logging = {
		Enabled = true,
		Verbose = true,
		Prefix = "Sushi Shop",
	},

	RecipeRemoteKey = 3.928131273829174e18,
	BuyStockRemoteKey = 93273987,
	SofaPosition = Vector3.new(-8.62709522, 35.5299988, -23.5437546),
}

shared.sushi_shop_simulator_settings = settings

return settings
